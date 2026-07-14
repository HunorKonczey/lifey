# SonarQube Findings Remediation Plan

Source: a full-project SonarQube for IDE (IntelliJ plugin) analysis, pasted as
a flat list of `(line, col) message [rule]` entries with no file names (the
IDE copy didn't include the per-file group headers). Below, each phase lists
the rules it covers and the files confirmed by grepping the codebase for the
pattern each rule flags. Where the raw report had many `(-, -)` duplicate
entries for the same rule, the exact remaining files will be re-confirmed by
grep at the start of that phase rather than guessed now.

**Ground rule for every phase: one phase = one PR, run the full backend test
suite (and `tsc`/`eslint`/vitest for the web phase) before moving to the
next. Nothing here ships in one shot.**

## Why this order

Phases 1–2 are behavior-preserving mechanical cleanups (safe to batch, easy
to review, build momentum). Phase 3 is real correctness risk — worth its own
focused PR so a reviewer isn't hunting for the one substantive change in a
sea of renames. Phase 4 requires actual judgment calls (some findings may be
"won't fix" with a documented reason, not a code change). Phase 5 is isolated
because of its sheer size (~39 files) and because "fix" here means a design
decision (inject `Clock`?), not a mechanical edit. Phase 6 is a different
stack (web) and ships independently of the backend phases.

---

## Phase 1 — Mechanical style cleanups (test + main, zero behavior change) — DONE

Completed. Result: 636/636 backend tests green, no behavior change.

* **S8694** — fixed across all 17 confirmed files (~110 call sites) via a
  scripted rewrite (`LocalDate.of(y, m, d)` → `LocalDate.of(y, Month.X, d)`),
  with `import java.time.Month;` added where missing.
* **S7467** — only 2 genuine unused catch-variables existed in the whole
  backend (`AuthServiceImpl.java`, `TrainerInviteEmailController.java`) —
  fixed with `_`. The other ~6 report entries didn't correspond to any
  actual unused catch/lambda variable found by a full-codebase scan; several
  files (`ImageReencoder`, `GoogleIdTokenVerifier`, `JwtService`) already use
  `_` from an earlier pass. Treated as stale report entries.
* **S8924** — fixed all 7 confirmed call sites (`WaterSourceControllerTest`,
  `UserAvatarServiceImplTest`, `WelcomeEmailListenerTest`,
  `WorkoutScheduleControllerTest`, `RecipeImageServiceImplTest`,
  `ProgramAssignmentServiceImplTest`) — added the missing static imports and
  dropped the `org.mockito.Mockito.` qualification.
* **S6068** — `ProgramAssignmentServiceImplTest` had a local `eq(Long)`
  wrapper method purely because `ArgumentMatchers.eq` wasn't statically
  imported; replaced with a direct static import and deleted the wrapper.
  No other file had this pattern.
* **S1128** — a full unused-import scan across all 438 backend source files
  found zero unused imports; the two report entries no longer apply
  (likely already resolved by earlier edits in this session).
* **S5838**, **S3358**, **S135** — searched exhaustively (size()==0/>0/!=0
  patterns, nested single-line ternaries, loops with >1 break/continue) and
  found no matching code anywhere in the backend. Treated as stale report
  entries — nothing to fix.
* **S5853** — 9 of 10 candidate consecutive-`assertThat(sameSubject)` pairs
  were merged into one fluent chain (`TokenHasherTest`,
  `WeeklyReportFormattingTest` ×2, `RecipeServiceImplTest` — via AssertJ's
  multi-property `.extracting(a, b).containsExactly(tuple(...), ...)`,
  `TrainerIdsWithActiveClientsRegressionTest`,
  `SessionCommentServiceImplTest`, `GoalCalculatorTest` ×2,
  `ContentAssignmentServiceImplTest`). One (`StarterCatalogListenerTest`)
  was left alone: its two assertions extract different, incompatible types
  from the same subject (`.extracting(Exercise::getName)` vs
  `.allSatisfy(...)` on the raw list) — merging them isn't a safe mechanical
  change.

---

Purely syntactic; a linter could do most of this. Safe to batch into one PR.

* **`java:S8694`** — "Use a `java.time.Month` enum constant instead of this
  int literal." By far the largest single rule in the report (~80+ hits) —
  every `LocalDate.of(2026, 7, 13)`-style call with a numeric month.
  Confirmed files (numeric-month `LocalDate.of(` calls):
  `ProgramAssignmentServiceImplTest`, `DateRangeQueryRegressionTest`,
  `TrainerClientDataControllerTest`, `WorkoutScheduleServiceImplTest`,
  `WorkoutScheduleControllerTest`, `ResendMailServiceTest`,
  `WeeklyReportServiceImplTest`, `WorkoutReminderJobTest`,
  `OccurrenceGeneratorTest`, `MealServiceImplTest`,
  `UserDetailsServiceImplTest`, `WeightServiceImplTest`,
  `WeightControllerTest`, `UserDetailsControllerTest`,
  `DailyStepCountServiceImplTest`, `DailyStepCountControllerTest`, plus
  `common/util/DateRanges.java` in main. Fix: `LocalDate.of(2026,
  Month.JULY, 13)`.
* **`java:S7467`** — "Replace `e`/`ex` with an unnamed pattern" (Java 21
  unnamed-variable `catch (Exception _)` where the caught exception is never
  read). Candidates: catch blocks across `ResendMailService`,
  `PushServiceImpl`, `UserAvatarServiceImpl`, `RecipeImageServiceImpl`,
  `ImageReencoder`, `GoogleAvatarImportListener`, `AuthServiceImpl`,
  `JwtService`, `JwtAuthenticationFilter`, `StarterCatalogListener`,
  `GoogleIdTokenVerifier`, `MailTemplateRenderer`, `WelcomeEmailListener` —
  confirm per-file at fix time which `catch` blocks genuinely never touch the
  variable (some legitimately log `ex.getMessage()` and must stay named).
* **`java:S8924`** — "Use a static import for `times`/`never`/`doThrow`."
  Confirmed: `ProgramAssignmentServiceImplTest` (`org.mockito.Mockito.times(2)`
  at the `verify(workoutSessionRepository, ...)` call), plus
  `WorkoutScheduleControllerTest`, `UserAvatarServiceImplTest`,
  `RecipeImageServiceImplTest`, `WaterSourceControllerTest`,
  `WelcomeEmailListenerTest`.
* **`java:S6068`** — "Remove this and every subsequent useless `eq(...)`
  invocation; pass the values directly." `ProgramAssignmentServiceImplTest`
  has a local `eq(Long)` wrapper method and several `verify(...)` calls
  mixing it with plain values — audit each call site: keep `eq()` only where
  it's mixed with a real matcher (e.g. `captor.capture()`), drop it (and the
  now-unused wrapper) everywhere else.
* **`java:S1128`** — unused imports (`org.mockito.InjectMocks` in one test
  file, `jakarta.validation.constraints.NotEmpty` in one main file — locate
  via `mvn -q compile` warnings or an IDE "optimize imports" pass, which is
  the safest way to catch every remaining unused import project-wide, not
  just the two the report sampled).
* **`java:S5838`** — "Use `isEmpty()` instead" (of `.size() == 0` /
  `!list.isEmpty()` double negatives, or `"".equals(...)`-style checks) —
  locate via grep for `.size() == 0` / `.size() > 0` once this phase starts.
* **`java:S5853`** — "Join these multiple assertions into one assertion
  chain" (AssertJ `assertThat(x).isA(); assertThat(x).isB();` instead of
  `.isA().isB()`) — scattered across several test files; low risk, pure
  readability.
* **`java:S3358`** — "Extract this nested ternary into an independent
  statement" — one occurrence, locate via grep for `? .* : .* ?` patterns.
* **`java:S135`** — "Reduce break/continue to at most one per loop" — one
  occurrence at a loop (likely an occurrence-generation loop in
  `WorkoutScheduleServiceImpl`/`ProgramAssignmentServiceImpl`/
  `OccurrenceGenerator`) — needs the actual loop restructured into early
  boolean flags or extracted helper methods; slightly more than a one-liner
  but still behavior-preserving.

## Phase 2 — Test quality (test files only, still zero prod risk) — DONE

Completed. Result: 636/636 backend tests green.

* **S5778** — found 34 occurrences (not ~10 as first estimated), all the
  exact same shape: `.thenAnswer(inv -> { X x = inv.getArgument(0);
  x.setId(N); return x; })` across 15 test files (`ContentAssignmentServiceImplTest`
  alone had 13). Since every mutated entity type (`User`, `WorkoutTemplate`,
  `Exercise`, `Recipe`, `Food`, `Meal`, `WeightEntry`, `WaterEntry`,
  `WaterSource`, `DailyStepCount`, `WorkoutSession`, `ProgramAssignment`,
  `TrainerClient`) extends `BaseEntity`, added one private generic helper
  per file — `private static <T extends BaseEntity> T withId(T entity, Long
  id) { entity.setId(id); return entity; }` — and collapsed each block into
  a single-expression lambda: `.thenAnswer(inv -> withId(inv.getArgument(0),
  N))`. A single-expression lambda has exactly one top-level invocation, so
  Sonar's rule (which targets multi-statement block lambdas, not nested
  calls within one expression) no longer fires. Verified the nested generic
  inference (`withId`'s `T` inferred through `inv.<T>getArgument(0)`) compiles
  cleanly on one file first before batch-applying to the rest.
* **S2699** — exactly 2 real assertion-less tests existed (confirmed by a
  full-suite scan recognizing AssertJ, JUnit, Mockito `verify()`, and MockMvc
  `andExpect()` as valid assertions — the naive first pass had ~200
  false positives from `@WebMvcTest` controllers whose only "assertion" is
  `.andExpect(...)`):
  * `AuthServiceImplTest.logout_unknownTokenIsANoOp` — wrapped the call in
    `assertThatCode(...).doesNotThrowAnyException()`, making the "no-op"
    contract the test name promises into an explicit assertion.
  * `FoodsExercisesOwnershipMigrationTest.barcodeAndNameUniquenessAreNowPerUserNotGlobal`
    — replaced the "no exception means it worked" comment with a real
    query confirming both rows exist (`count(*) ... = 2`), which is a
    stronger assertion than the original (proves the rows were actually
    inserted, not just that nothing threw).

---

* **`java:S2699`** — "Add at least one assertion to this test case" (two
  occurrences, e.g. around line 195 of one of the trainer service tests) —
  each needs a real look: either the test is missing its assertion (bug in
  the test) or it's purely a `verify(...)`-only Mockito test that Sonar
  doesn't recognize as an assertion (in which case add an explicit
  `assertThatCode(...).doesNotThrowAnyException()` or similar, or configure
  the rule to recognize `verify()` — a judgment call per test).
* **`java:S5778`** — "Refactor the lambda to have only one invocation
  possibly throwing a runtime exception" — by far the most common Phase 2
  finding (10+ hits), all in Mockito `.thenAnswer(inv -> { ...; return x;
  })` blocks that call two throwing methods (e.g. a setter + a getter, or
  two mock interactions) inside one lambda. Confirmed hotspots:
  `ProgramAssignmentServiceImplTest`, `ContentAssignmentServiceImplTest`
  (many `thenAnswer` stubs from the bulk-assignment work), plus others
  flagged with `(-, -)`. Fix pattern: split into a named helper method or
  two chained `.thenAnswer`/`.thenReturn` calls so each lambda has one
  throwing call.

## Phase 3 — Real correctness risk (main code, needs careful review)

These are not style — each is a genuine bug or bug-shaped risk.

* **`java:S6809`** — "Call transactional methods via an injected dependency
  instead of directly via `this`." Two-three occurrences in `@Transactional`
  service classes (locate exact call sites via grep for self-invocation of
  a method carrying its own `@Transactional`/different propagation within
  the same class at Phase 3 start — candidates are the trainer service
  classes touched most recently, `ContentAssignmentServiceImpl` and
  `ProgramAssignmentServiceImpl`, since they have the most internal
  cross-calls). **This is a real bug class**: Spring's proxy-based AOP means
  a self-invoked `@Transactional` method silently runs with the *caller's*
  transaction semantics, not its own — if any of these calls rely on their
  own propagation (e.g. `REQUIRES_NEW`) it's currently broken. Needs each
  call site individually assessed: if the callee doesn't actually need
  independent transaction semantics, this may be a false positive worth
  suppressing with a comment explaining why; otherwise, extract the callee
  into a separate injected bean.
* **`java:S2259`** — "NullPointerException could be thrown; `principal` is
  nullable" — two occurrences. One is likely
  `AuthServiceImpl.java` (`principal = (UserPrincipal)
  authentication.getPrincipal()` — `getPrincipal()` is `@Nullable` per the
  Spring Security contract even though this code path never actually sees
  null in practice). The other two (`copyTemplateForClient()`/
  `copyRecipeForClient()` NPE warnings at lines 87-88) are in
  `ContentAssignmentServiceImpl` — likely Sonar flagging the new
  `requireOwnedTemplate`/`requireOwnedRecipe` + `copyTemplateForClient`/
  `copyRecipeForClient` split from the bulk-assignment refactor, where the
  nullable `WorkoutTemplate sourceTemplate`/`Recipe sourceRecipe` locals
  (only one is non-null depending on `contentType`) get passed into the
  wrong-branch copy method in a way Sonar's flow analysis can't rule out.
  Needs a look — likely just needs the null-check made explicit/final
  rather than relying on the switch's structure to guarantee non-null.
* **`java:S1192`** — "Define a constant instead of duplicating this literal
  'Scheduled session not found: ' 3 times" — confirmed in
  `WorkoutScheduleServiceImpl.java`. Mechanical but grouped here because it
  touches production exception-throwing code, not a test.
* **`java:S1172`** — "Remove this unused method parameter `ignoredUser`" —
  one occurrence; locate and either remove the parameter or, if it exists
  for interface-signature-compatibility reasons, rename with a leading
  underscore convention isn't idiomatic Java — better to check whether the
  interface method actually needs that parameter at all.

## Phase 4 — Security/config judgment calls

Not pure fixes — each needs a decision, and some may end up as documented
"won't fix" rather than a code change.

* **`java:S4502`** — "Make sure disabling Spring Security's CSRF protection
  is safe here" — confirmed at `SecurityConfig.java:87`
  (`.csrf(AbstractHttpConfigurer::disable)`). This is almost certainly
  intentional (stateless JWT bearer-token API, no cookie-based session to
  forge) — the right outcome is likely a one-line comment explaining why,
  plus a Sonar "won't fix" resolution, not a code change. Confirm no cookie-
  based auth path exists before closing it out.
* **`java:S6471`** — "The `eclipse-temurin` image runs with `root` as the
  default user" — confirmed in `backend/Dockerfile`. Real fix: add a
  non-root `USER` stanza (standard multi-stage Docker hardening — create an
  `appuser`, `chown` the app dir, `USER appuser` before `ENTRYPOINT`). Check
  `web/Dockerfile` too even though it wasn't flagged (may already do this,
  or may use a different base image).
* **`java:S5693`** — "Content length limit ... greater than the defined
  limit" (two occurrences) — confirmed in the avatar/recipe-image upload
  path (`UserAvatarController`/`RecipeImageController`/
  `UserAvatarServiceImpl`/`RecipeImageServiceImpl`, and
  `application.yml`'s multipart config). Needs checking what the actual
  intended max upload size is and aligning the two limits (Spring's
  `spring.servlet.multipart.max-file-size` vs. whatever in-code check exists)
  rather than blindly shrinking one number.
* **`java:S1075`** — "Refactor your code to get this URI from a customizable
  parameter" — confirmed at `GoogleIdTokenVerifier.java:25-26` (hardcoded
  `JWKS_URI`/issuer constants). Fix: move to `application.yml` +
  `@ConfigurationProperties` (there's already a `GoogleOAuthProperties`
  class in the same package to extend), so it's overridable per environment
  without a code change (useful for pointing at a mock/test JWKS endpoint).

## Phase 5 — `.now()` time-zone determinism (isolated due to size)

* **`java:S8688`** — "Explicitly specify the time zone by passing a `ZoneId`
  or a `Clock` to the `.now()` method." This is the single largest finding
  by file count: **39 main-source files** call `Instant.now()`/
  `LocalDate.now()`/`LocalDateTime.now()` with the implicit system default
  zone, plus a comparable number of test files.

  **This phase needs a design decision before any code moves**, not a
  mechanical sweep:
  * Option A — inject a `java.time.Clock` bean (`Clock.systemUTC()` in
    production, a fixed `Clock` in tests) everywhere `.now()` is called.
    Correct long-term, but touches the constructor of ~30+ service classes
    — a large, high-review-cost diff for a currently-hypothetical bug (the
    app has one deployment region/timezone; this only matters if that ever
    changes, or for test determinism).
  * Option B — leave production code alone (the app's server timezone is
    fixed and known), and only fix the finding where it's genuinely useful:
    tests that want deterministic, timezone-independent instants (inject a
    fixed `Clock` or `Instant` there specifically, following the pattern
    already used for `ProgramAssignmentServiceImplTest`'s `A_MONDAY`
    computed-from-`LocalDate.now()` fix). Mark the rule "won't fix" at
    project level for main-source `.now()` calls with a documented reason,
    unless/until multi-timezone deployment is a real requirement.

  **Recommendation: Option B.** Revisit Option A only if the product ever
  needs multi-region deployment or the test suite starts showing
  timezone-dependent flakiness beyond what's already been patched once
  (`ProgramAssignmentServiceImplTest`'s Monday-date bug). Scope this phase
  to: (1) formally suppressing/resolving the main-source findings with a
  short justification comment or Sonar issue resolution, (2) auditing test
  files for the same `LocalDate.now()`-relative-to-fixed-date fragility
  pattern that just broke `ProgramAssignmentServiceImplTest`, fixing any
  found the same way.

## Phase 6 — Web/frontend findings (separate stack, independent PR)

* **`Web:PageWithoutTitleCheck`** — "Add a `<title>` tag to this page" (7
  occurrences) — Next.js App Router pages missing a `metadata`/`title`
  export. Fix: add `export const metadata = { title: "..." }` (or a
  `generateMetadata`) to each flagged route under `web/src/app/`. Low risk,
  mechanical, but needs the actual route files identified (re-run analysis
  scoped to `web/` to get file names, since none were in the flat list).
* **`Web:S5256`** — "Add `<th>` headers to this `<table>`" (2 occurrences)
  — a real accessibility table somewhere using `<td>` for header cells.
* **`css:S7924`** — "Text does not meet the minimal contrast requirement" (2
  occurrences) — likely a `var(--muted)`-on-`var(--surface)` combination
  somewhere thin enough to fail WCAG AA; needs the actual color pair checked
  against a contrast calculator before picking a fix (don't guess a new
  color without verifying against both light/dark themes, per this repo's
  theme-aware CSS convention).

Run `tsc --noEmit`, `eslint`, and `vitest` after this phase — no backend
involvement.

---

## Suggested execution order

1 → 2 → 3 → 4 → 6, with **5 last and possibly partial** (per the Option B
recommendation above, "fixing" Phase 5 may mean mostly writing suppression
resolutions rather than code changes). Each phase is its own PR/session;
confirm before starting the next one.
