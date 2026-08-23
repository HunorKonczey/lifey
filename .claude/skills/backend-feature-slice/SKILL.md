---
name: backend-feature-slice
description: Add a REST feature or entity to the Spring Boot backend under backend/src/main/java/com/lifey/. Use when building a new endpoint, a new persisted business entity, or extending an existing feature with an operation the mobile or web client will call — covers ownership scoping, soft delete, the delta-sync feed, DTO validation, and the required tests. Not for Flutter work, and not for schema-only changes (use the flyway-migration skill for those).
---

# New backend feature slice (Spring Boot)

`backend/CLAUDE.md` is the reference for **package layout** — read it for where
files go and when a `service/`/`exception/`/`entity/` subpackage is warranted.
This skill covers what that document does not: the code patterns every slice
has to get right, in the order you build them.

Reference slice to copy: `com/lifey/weight/` — one entity, user-scoped, soft
delete, delta-sync feed, paged and range queries. `com/lifey/water/` is the
same shape with two entities and a relation.

## The two rules that outrank everything else

1. **Every business entity belongs to a user.** Not "usually" — every query in
   the repository is scoped by `userId`, and every lookup-then-mutate goes
   through `findByIdAndUserId`. A repository method that takes an id but no
   user id is a data leak waiting for a guessed id.
2. **A migration must never name `chat_conversations`, `chat_messages`,
   `chat_participants` or `chat_message_attachments`** — those belong to the
   `lifey-chat` service. `devops/check-schema-ownership.sh` fails the build.
   See `backend/CLAUDE.md` for the full rule.

## 1. Entity

Extend `SyncableEntity` if the mobile app caches this entity offline (it adds
`updatedAt`/`deletedAt` and the `@PrePersist`/`@PreUpdate` callbacks that keep
`updatedAt` fresh). Extend `BaseEntity` only for server-only data that never
reaches the offline cache.

```java
@Getter
@Setter
@Entity
@Table(name = "weight_entries")
public class WeightEntry extends SyncableEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "entry_date", nullable = false)
    private LocalDate date;
}
```

`fetch = LAZY` on every `@ManyToOne` — an eager user association loads the
whole `User` on every row of every list query.

`spring.jpa.hibernate.ddl-auto` is **`validate`**: the entity and the Flyway
migration must agree exactly, or the application fails to start. Write the
migration in the same change (see the `flyway-migration` skill).

## 2. Repository

Derived queries, always user-scoped. Two families:

```java
// normal reads — hide tombstones
List<WeightEntry> findAllByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(Long userId);

// ownership-checked single lookup, for update/delete
Optional<WeightEntry> findByIdAndUserId(Long id, Long userId);

// delta-sync feed — deliberately NOT deletedAt-filtered: the client needs the
// tombstones in order to delete its local rows
Page<WeightEntry> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);
```

For an optional range bound, pass `DateRanges.DISTANT_PAST`/`DISTANT_FUTURE`
rather than null. A `(:from is null or w.date >= :from)` predicate looks
cleaner and breaks on Postgres — it cannot infer a type for a parameter used
only in an `is null` check, and the failure only appears when exactly one bound
is non-null. `WeightEntryRepository` carries the full story in a comment; don't
undo it.

## 3. Service — interface + `Impl`, always

Even for trivial CRUD (a project convention, see `backend/CLAUDE.md`).

```java
@Service
@Transactional
@RequiredArgsConstructor
public class WeightServiceImpl implements WeightService {

    private final WeightEntryRepository repository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;
```

- **Ownership lives here**, not in the controller: every method starts from
  `currentUserProvider.getUserId()`. Services never take a `userId` parameter
  from the web layer. The exception is a deliberate cross-user method (e.g.
  `findAllForUser` for the trainer endpoints) — those must be authorized by the
  caller first (`TrainerAccessService.requireActiveClient`) and must say so in
  the interface's javadoc.
- Constructor injection via `@RequiredArgsConstructor` + `final` fields.
- `@Transactional(readOnly = true)` on every query method.
- Attach the owner with `userRepository.getReferenceById(userId)` — a proxy, no
  select needed.
- **Delete is a soft delete** for `SyncableEntity`: load with
  `findByIdAndUserId(...)`, `orElseThrow(ResourceNotFoundException::new)`, then
  `entity.setDeletedAt(Instant.now())`. No `save()` — dirty checking inside the
  transaction handles it. A hard delete strands the mobile client, which learns
  about deletions only from tombstones.
- Never call one `@Transactional` method from another in the same class — it
  bypasses the proxy. Extract a plain private method and call that from both
  (`findAllForUserInternal` is the precedent).

## 4. Mapper and DTOs

Mapper: `final` class, private constructor, `public static` methods.

```java
public static WeightResponse toResponse(WeightEntry entry) {
    return new WeightResponse(entry.getId(), entry.getDate(), entry.getWeight(),
            entry.getUpdatedAt(), entry.getDeletedAt());
}
```

Response DTOs for synced entities **must expose `updatedAt` and `deletedAt`** —
the mobile pull reads both. DTOs are `record`s in `dto/`, requests carry
jakarta validation annotations (`@NotNull`, `@Positive`, `@PastOrPresent`,
`@Size`), and the controller enforces them with `@Valid`.

## 5. Controller

```java
@Tag(name = "Weight Tracking", description = "Daily body-weight entries")
@RestController
@RequestMapping("/api/v1/weights")
@RequiredArgsConstructor
public class WeightController {
```

- Base path is always `/api/v1/<plural-kebab>`.
- `@Operation(summary = ...)` on every method — springdoc publishes it.
- Status codes: POST → `@ResponseStatus(HttpStatus.CREATED)`,
  DELETE → `NO_CONTENT`, everything else default 200.
- The controller does no business logic and no ownership checks; it validates,
  delegates, and returns.

**The delta-sync feed is a second GET on the same path**, separated by the
presence of the query parameter:

```java
@GetMapping(params = "!updatedSince")
public List<WeightResponse> findAll(...) { ... }

@GetMapping(params = "updatedSince")
public Page<WeightResponse> findDelta(@PageableDefault(size = 200) Pageable pageable,
                                      @RequestParam Instant updatedSince) { ... }
```

Ordering for the delta feed is fixed server-side to `updatedAt asc, id asc` —
build the `Pageable` in the service, don't take the client's sort. Skipping
this endpoint means the mobile client can only ever do a full pull.

## 6. Migration

New table or column → new Flyway migration in the same change. Use the
`flyway-migration` skill; do not hand-write it from memory.

## 7. Tests — both layers

Controller (`src/test/java/com/lifey/<feature>/<X>ControllerTest.java`):

```java
@WebMvcTest(WeightController.class)
class WeightControllerTest {
    @Autowired MockMvc mockMvc;
    @MockitoBean WeightService weightService;
```

Assert status, JSON shape via `jsonPath`, and that the right service method was
chosen (`verify(service, never()).findAll()` when params should route
elsewhere).

Service (`.../<feature>/service/<X>ServiceImplTest.java`):

```java
@ExtendWith(MockitoExtension.class)
class WeightServiceImplTest {
    @Mock WeightEntryRepository repository;
    @Mock CurrentUserProvider currentUserProvider;
    @InjectMocks WeightServiceImpl service;
```

Cover at minimum: **a foreign id is rejected** (`findByIdAndUserId` empty →
`ResourceNotFoundException`), delete sets `deletedAt` instead of removing, and
the delta query is called with the fixed sort.

## 8. Verify

```bash
./devops/check-schema-ownership.sh && cd backend && ./mvnw -B verify
```

Both are what CI runs. `verify` starts a Postgres via Testcontainers, so Docker
must be running; it also runs Flyway against that database, which is how a
migration/entity mismatch surfaces before deploy.

## Definition of done

- [ ] Entity extends `SyncableEntity` (offline-cached) or `BaseEntity`, owner
      mapped `@ManyToOne(fetch = LAZY, optional = false)`
- [ ] Every repository method scoped by `userId`; mutating lookups use
      `findByIdAndUserId`
- [ ] Service interface + `Impl`; ownership resolved from `CurrentUserProvider`
- [ ] Delete is a tombstone, not a row removal (for synced entities)
- [ ] Response DTO exposes `updatedAt` + `deletedAt`; request DTO validated
- [ ] `?updatedSince` delta endpoint present, fixed `updatedAt,id` ordering
- [ ] Flyway migration written; no chat-owned table named
- [ ] Controller test + service test, including the foreign-id rejection
- [ ] `check-schema-ownership.sh` + `./mvnw -B verify` clean
- [ ] Mobile counterpart planned (see the `flutter-feature-slice` skill) — an
      endpoint with no client is half a feature
