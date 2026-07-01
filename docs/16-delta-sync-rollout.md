# 16 – Delta sync rollout plan (post-Foods)

Status: planning only — no implementation. Written so a future session can
pick one entity from §3 and go, without re-deriving this analysis.

Foods finished the full track: [14-pagination-plan.md](14-pagination-plan.md)
Phases 1–2 (UI pagination + pageable/searchable backend endpoint) and
[15-delta-sync.md](15-delta-sync.md) Phase 3 (delta sync), all implemented and
verified live against the real backend. This doc surveys every other entity
`PullEngine.pullAll()` pulls and plans the same rollout for them — but flags
three ways the Foods recipe does **not** generalize as-is, because Foods has
three properties none of the others share:

1. **Foods has no `userId`** — it's a shared global catalog. Every other
   entity below is user-scoped (`existsByIdAndUserId`/`deleteByIdAndUserId`
   throughout their `ServiceImpl`s). A delta feed for any of them **must**
   filter by the current user, or one user's edits leak into another's pull.
   This is the single easiest way to get this rollout wrong — see §2.1.
2. **Foods already had a soft-delete concept** (`hidden`) before delta sync;
   the pilot only had to add a *second*, single-purpose `deletedAt` column
   alongside it. Every other entity below does a genuine **hard delete**
   today (`repository.deleteByIdAndUserId(...)`). Introducing a tombstone
   means introducing soft-delete itself for the first time on these tables —
   a bigger, riskier change than what Foods needed. See §2.2.
3. **Foods is a flat entity** — no child rows. Meals, Recipes, Workout
   Templates, and Workout Sessions each sync a parent + one or two child
   tables in the same pull, today reconciled by a delete-then-reinsert of
   children inside a transaction (see each `_pull*`'s `_deleteMissing(...,
   onDelete: ...)` in `pull_engine.dart`). Delta sync needs an explicit
   decision for how children are represented in the feed — see §2.3.

## 1. Entity inventory

| Entity | Backend entity (`com.lifey...`) | User-scoped? | Delete today | Children synced with it | Mobile Drift table(s) | Expected per-user growth | Phase 1 (local pagination) |
|---|---|---|---|---|---|---|---|
| Foods | `nutrition.food.Food` | No (global) | Soft (`hidden`) + tombstone (done) | — | `Foods` | Large, shared catalog | **Done** |
| Meals | `nutrition.meal.Meal` + `MealEntry` | Yes | Hard, ORM-cascades entries (`CascadeType.ALL, orphanRemoval=true`) | `MealEntry` (FK `meal_id`, no DB cascade — relies on ORM cascade) | `Meals`, `MealEntries` | Fast — several/day | **Done** |
| Recipes | `nutrition.recipe.Recipe` + `RecipeIngredient` | Yes | Hard, ORM-cascades ingredients | `RecipeIngredient` (FK `recipe_id`, no DB cascade) | `Recipes`, `RecipeIngredients` | Slow — user-curated, dozens | Open (1.3) |
| Exercises | `workout.exercise.Exercise` | No (shared, like Foods — seeded + user-added) | **Hard, no cascade, no ORM cascade** — referenced by `workout_template_exercises`/`workout_session_exercises` with plain FKs. Deleting a used exercise likely throws a DB constraint violation today; pre-existing gap, not caused by this rollout. | — | `Exercises` | Slow — seeded + user-added, dozens–low hundreds | Open (1.3) |
| Workout templates | `workout.template.WorkoutTemplate` + `WorkoutTemplateExercise` | Yes | Hard, ORM-cascades template-exercise links | `WorkoutTemplateExercise` (FK `workout_template_id`, no DB cascade) | `WorkoutTemplates`, `WorkoutTemplateExercises` | Slow — user-curated, dozens | Open (1.3) |
| Workout sessions | `workout.session.WorkoutSession` + `WorkoutSessionExercise` + `ExerciseSet` | Yes | Hard, ORM-cascades both child tables | `WorkoutSessionExercise` + `ExerciseSet` (session-exercise FK has DB-level `on delete cascade`; sets don't, rely on ORM) | `WorkoutSessions`, `WorkoutSessionExercises`, `ExerciseSets` | Moderate — per workout, ~3–5/week | Open (1.3) |
| Weight entries | `weight.WeightEntry` | Yes | Hard, no children | — | `WeightEntries` | Slow-moderate — ~daily | Not started |
| Water entries | `water.WaterEntry` | Yes | Hard, no children | — | `WaterEntries` | Fast — several/day | Not started |
| Water sources | `water.WaterSource` | Yes | Hard, no children | — | `WaterSources` | Tiny — a handful, ever | Not started |
| Daily step counts | `steps.DailyStepCount` | Yes | Hard, no children | — | `DailyStepCounts` | Slow — exactly 1/day | Not started |
| Settings | `settings.UserSettings` | Yes (singleton) | N/A (no delete) | — | `UserSettingsTable` | None — always 1 row | N/A |

None of these have any `Pageable`/`Page<`/searchable repository method today
(confirmed by grep) — Foods is still the only entity with that pattern.

## 2. Where the Foods recipe needs to change

### 2.1 User-scoping the delta query (critical, do not skip)

Foods' delta repository method is `findByUpdatedAtGreaterThanEqual(Instant
since, Pageable pageable)` — global, no owner filter, because Foods has none.
Every other entity's equivalent **must** be
`findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since,
Pageable pageable)`, with `userId` coming from `CurrentUserProvider` exactly
like every other query in these services already does. Copying Foods'
repository method signature verbatim and forgetting the `userId` filter would
leak every user's changes to every other user's mobile pull — a real data
leak, not a cosmetic bug. Call this out explicitly in whichever prompt does
the backend work for the next entity.

### 2.2 Converting hard delete to soft delete + tombstone

Foods' `delete()` only needed one added line (`setDeletedAt(...)`) because
`hidden` already existed. For every other entity, `delete()` today is:

```java
if (!repository.existsByIdAndUserId(id, userId)) throw new ResourceNotFoundException(...);
repository.deleteByIdAndUserId(id, userId);
```

Delta sync requires this to become an update instead of a delete — set
`deletedAt`, keep the row. That has knock-on effects that Foods' rollout
didn't have to deal with:

- Every existing `findBy...` query for that entity (list, by-id, whatever the
  feature uses) must now exclude soft-deleted rows, the same way Foods'
  `findAllByHiddenFalseOrderByName` always excluded `hidden = true`. Audit
  each entity's repository for every finder used by non-delta endpoints.
- The unpaged/normal list endpoints for these entities today just call
  `deleteByIdAndUserId` and the row is gone — no existing test asserts
  "deleted rows don't reappear," because hard delete makes that automatic.
  Converting to soft delete needs new tests proving the same invariant holds
  once rows merely get flagged instead of removed.
- Existing `deleteByIdAndUserId` / `existsByIdAndUserId` repository methods
  become dead code (or need renaming/repurposing) once delete is soft —
  clean these up rather than leaving an unused hard-delete path around.

This is real, per-entity work — budget for it, don't treat it as "just add
two columns" the way Foods' migration was.

### 2.3 Parent + child aggregates: don't delta-sync children independently

Meals/Recipes/Workout Templates/Workout Sessions each have 1–2 child tables
synced in the same pull. Recommendation: **only the parent gets
`updated_at`/`deleted_at` and a delta feed.** Children are never
independently delta-synced or tombstoned. Instead:

- Whenever a parent shows up in the delta feed (upsert *or* tombstone), the
  mobile client replaces *all* of that one parent's local children —
  the exact delete-then-reinsert-inside-a-transaction pattern already used by
  today's `_pullMeals`/`_pullRecipes`/`_pullWorkoutTemplates`/
  `_pullWorkoutSessions`, just scoped to a single row's worth of children
  instead of the whole table's.
- This means editing *only* a child (e.g. changing one recipe ingredient's
  quantity, with the recipe's own name/description untouched) must still bump
  the **parent's** `updated_at` — otherwise that change never appears in the
  parent's delta feed at all. This has to be explicit in each service: an
  ingredient/entry/set write needs to touch its parent row (even a no-op
  field write is enough to trigger the parent's own `@PreUpdate`) so the
  parent's `updated_at` advances. Flag this as an explicit acceptance test
  per entity — it's the easiest part of this whole rollout to silently get
  wrong, since it only shows up as a bug when a child-only edit fails to sync
  to a second device.
- Alternative considered and rejected for now: giving every child table its
  own `updated_at`/tombstone and delta-feed. Rejected because it multiplies
  the work in §2.1/§2.2 across 6 more tables for no real benefit — the mobile
  client already needs to fetch a parent's full child set on any parent
  change (there's no meaningful way to "partially" sync one ingredient
  without its recipe), so tracking children independently buys nothing.

## 3. Priority order and reasoning

1. **Weight entries, Water entries, Daily step counts** — do these three
   first, *before* any of the aggregate entities. They're structurally
   closest to a "second Foods" (flat, no children) while still forcing the
   real generalization work: user-scoping (§2.1) and hard→soft delete
   conversion (§2.2), without also taking on §2.3's parent/child complexity.
   Proving the recipe generalizes on a simple entity before tackling a
   complex one is worth the ordering. Water entries has the fastest growth
   of the three (several/day) — start there if picking just one.
2. **Meals** — highest real value (fastest-growing list of all the
   aggregates) and a good first test of §2.3's parent-touches-child-on-edit
   requirement, since meal entries change independently of the meal's own
   fields reasonably often (grams edited, food swapped).
3. **Workout sessions** — same shape as Meals but with two child tables
   instead of one (session-exercises + sets); do after Meals once §2.3's
   pattern is validated once already.
4. **Recipes, Workout templates, Exercises** — lowest priority. All are
   user-curated and bounded to dozens of rows in practice; delta sync buys
   little here compared to the aggregates above. Do these last, mostly for
   consistency across the codebase rather than a real scalability need.
   Exercises additionally needs someone to actually fix (or at least
   document) the pre-existing delete-of-a-used-exercise gap noted in §1
   before or alongside its soft-delete conversion.
5. **Water sources** — skip indefinitely. A handful of rows per user, ever;
   not worth the soft-delete conversion cost.
6. **Settings** — never. Singleton row, always fetched whole; delta sync is
   meaningless for it.

Also worth deciding per entity, independently of delta sync: does it need a
**Phase 2** paged+searchable endpoint at all? Foods needed one because the
web `FoodsView` table was fetching an unbounded shared catalog. None of these
other entities have an unbounded *web-facing* list problem today (they're all
either small/curated or capped at roughly one-per-day) — so Phase 2 (the
`params = "page"` handler, search support) is likely **not needed** for any
of them purely for delta sync's sake. The `updatedSince` param can be added
as a much lighter, standalone addition (e.g. `GET /weights?updatedSince=...`,
still paged via `page`/`size` for response-size safety, but without ever
building out `search` or a client-sort story) unless a future feature
independently needs web-side pagination for one of these lists.

## 4. Per-entity task template (fill in `<Entity>` and go)

Mirrors the Prompt 2.1/2.2/2.3/3.1 style from docs 14 and 15.

### Prompt A — soft-delete + delta-sync backend for `<Entity>`
```
Read backend/src/main/java/com/lifey/<package>/<Entity>.java, <Entity>Controller.java,
<Entity>Service.java, <Entity>ServiceImpl.java, <Entity>Repository.java, and their
existing tests. Also read docs/16-delta-sync-rollout.md §2.1 and §2.2 before starting.

1. Add `updatedAt` (Instant, not null) and `deletedAt` (Instant, nullable) to
   <Entity>, bumped via @PrePersist/@PreUpdate (same pattern as Food.java —
   do not add a DB trigger; nothing in this codebase writes to these tables
   outside JPA). Add the Flyway migration (next V-number) with a composite
   index on (updated_at, id).
2. Convert delete() from a hard repository.deleteByIdAndUserId(...) to
   setting deletedAt (keep existing 404-if-missing check). Audit every
   existing finder this entity's controller/service uses and confirm none of
   them need an explicit "not deleted" filter added (list this explicitly in
   your summary — don't just assume).
3. Add a user-scoped delta repository method:
   findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since,
   Pageable pageable) — THIS MUST FILTER BY userId. Wire it into the service
   and an optional `updatedSince` param on the existing (or new, if this
   entity had no pageable variant yet) paged handler, fixed `updatedAt,id`
   ascending order when present, exactly like FoodController/FoodServiceImpl.
4. Add the entity's DTO's `updatedAt`/`deletedAt` fields.
5. Tests: soft-delete behavior (deleted rows excluded from normal
   endpoints, present with deletedAt set in the delta feed), delta feed
   user-scoping (a second user's rows never appear), and — if this entity has
   children (§2.3) — a test proving an edit to only a child bumps the
   parent's updatedAt.
```

### Prompt B — mobile delta pull for `<Entity>`
```
Read mobile/lib/core/sync/pull_engine.dart's _pull<Entity> and (if applicable)
its onDelete child-cleanup callback, plus _pullFoods/_pullFoodsFull/_pullFoodsDelta
as the reference implementation, and docs/16-delta-sync-rollout.md §2.3 if this
entity has child tables.

Add the same two-branch structure Foods has: no sync_cursors row for
'<entity>' -> today's full bootstrap pull unchanged (including its existing
child-table onDelete cleanup); cursor present -> delta pull via updatedSince,
upsert-or-tombstone per row, and if this entity has children, replace ALL of
that one row's local children on every upsert (not just on first insert) —
do not call the full-table _deleteMissing on this path. Reuse
_getAllPages/_getSyncCursor/_setSyncCursor as-is; no new sync-cursor
infrastructure needed, sync_cursors already supports any entityType string.
```

### Prompt C — verification
```
Same manual verification loop used for Foods: run the entity's backend unit
tests, then hit the real endpoint via curl against the running dev backend —
create a row, confirm it appears in the delta feed; delete it, confirm the
tombstone appears with deletedAt set and the row is absent from the normal
list endpoint; if it has children, edit only a child and confirm the parent's
updatedAt bumped and it reappears in the delta feed. Then run the mobile
pull_engine tests (mirroring pull_engine_delta_sync_test.dart) and confirm
flutter analyze is clean.
```
