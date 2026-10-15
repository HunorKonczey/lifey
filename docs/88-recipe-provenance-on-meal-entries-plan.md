# 88 – Recipe Provenance on Meal Entries

Status: planned — not started (Jira umbrella LIF-166; steps LIF-167 … LIF-176 under epic LIF-6)
Scope: backend · mobile · web — one migration (`V95`), API field, offline sync, no new endpoint
Depends on: docs/87-add-recipe-to-meal-plan.md (the flows that put a recipe into a mixed meal —
only the *stamping* steps M3/W2 wait for it), docs/15-delta-sync.md and
docs/16-delta-sync-rollout.md §2.3 (meals are delta-synced as a whole; entries never
independently)

docs/87 lets a recipe's ingredients join a meal as ordinary entries. That works
because an entry is just `{food, grams}` — and that is also its cost: **the meal
forgets which recipe the rows came from.** Today the only trace is `meals.name`,
set when a recipe is logged as a meal of its own, and web `computeRecipeUsage`
finds recipe usage by matching that name. Consequently:

- a recipe added into a mixed meal (docs/87) is invisible to recipe usage — the
  "Recent" filter, a "most used" ranking and the mobile picker's ordering
  cannot know about it;
- renaming a recipe orphans its whole history (the name no longer matches);
- a meal can show nothing but a flat list of foods where the user thinks of
  "the chilli and a salad".

This plan stores the provenance on the entry itself: `meal_entries.recipe_id`.

## 1. What we're building

1. **Backend.** `meal_entries.recipe_id` (nullable FK, `on delete set null`);
   `MealEntryRequest.recipeId`; `MealEntryResponse.recipeId` + `recipeName`. A
   one-off backfill tags the entries of existing recipe-named meals.
2. **Mobile data.** `meal_entries.recipe_client_id` in the local DB, carried
   through every write path (create, edit, duplicate, copy-day), pushed as an
   optional reference, resolved on pull.
3. **Recipe usage that is true.** A recipe counts as *used* once per meal that
   has at least one entry tagged with it — regardless of name, mixing or
   renaming. Web `computeRecipeUsage` and a new mobile `recipeUsageProvider`
   read it; the mobile recipe picker (docs/87) sorts "last used" first.
4. **Grouped display.** The mobile meal editor and the web meal card show the
   entries of one recipe as one group ("Chilli · 3 items · 520 kcal"), next to
   the loose foods of the same meal.
5. **When a client does not tag** (nothing sends `recipeId`), the meal behaves
   exactly as today: plain entries, no group, name-keyed legacy rules only for
   meals that no entry tags (see 2.5).

## 2. Key design decisions

### 2.1 The tag lives on the entry, not on the meal — and is a plain recipe id

`meal_entries.recipe_id bigint null references recipes (id) on delete set null`,
no further columns.

- Rejected: a recipe *group id* per add (one uuid per "I added the chilli")
  so two adds of the same recipe to one meal stay two groups, with a
  servings count. It needs a second column, a new id on every client and a
  merge rule for the web's "latest plain meal" write; nothing in the product
  asks for it yet. Two adds of the same recipe to one meal show as **one**
  group; the amount is the sum of its entries. If "2 servings of chilli" ever
  needs to be a number, it is derivable from grams or added later without
  breaking this column.
- Rejected: tagging the meal (`meals.recipe_id`). A mixed meal has several
  recipes; and the tag must survive per-ingredient edits and removals, which
  are entry-level operations.
- `on delete set null`: recipes are soft-deleted in practice
  (`recipes.deleted_at`), so the FK only fires on hard deletes (account
  deletion cascades the meals anyway). Null is the honest value when the recipe
  is truly gone.

### 2.2 An entry keeps its tag when its grams change; nothing else clears it

Editing the grams of a tagged entry, or swapping nothing but the quantity,
leaves it in the group — "I had less of the rice" is still the chilli. Removing
the entry removes it from the group. There is deliberately **no** "detach from
recipe" action (Non-goals). Entries added by other means (food search, macros,
photo estimate) are untagged and stay loose.

### 2.3 The API contract: absent `recipeId` clears the tag

Meal update is "replace all entries" (`MealServiceImpl.replaceEntries`
rebuilds the list from the request). So a client that sends an entry without
`recipeId` *removes* the provenance of that entry. This is the correct, simple
semantic — and the single biggest risk of the plan, because **every client write
path rebuilds entries from scratch**: web `mealEdit.ts`, `copyMeal.ts`,
`copyFromDay.ts`, `FoodPreviewPane` / `mealMerge.ts`, and mobile
`MealRepository.update` / `duplicateMeal` / `copyMeals` /
`LogMealScreen._persist`. See §6 (Risks) and steps W1, M2.

- Rejected: server-side "keep existing tag when the field is missing". It makes
  clearing impossible, needs entry identity across updates (entries have no
  stable id on the wire), and hides client bugs instead of surfacing them in
  a contract test.

### 2.4 The server accepts a soft-deleted recipe, rejects someone else's

`replaceEntries` resolves `recipeId` with `findByIdAndUserId` **without** the
`deleted_at is null` filter: a recipe deleted on another device between the
meal being logged offline and synced must not fail the whole meal. A recipe
that is not the caller's (or does not exist) → `ResourceNotFoundException`
(404), exactly like a foreign `foodId`.

### 2.5 Usage is derived from tags; the name rule survives only for untagged legacy meals

`computeRecipeUsage` (web) and the new mobile `watchRecipeUsage` count a meal as
one use of recipe *R* when any of its entries has `recipeId == R`, with the
same 90-day window as food usage. The name match (`meal.name` ↔ recipe name) is
removed from usage.

- The one-off backfill (B1) tags the entries of existing named meals, so
  history is not lost. Where the name is ambiguous it tags nothing (2.6).
- `isRecipeMeal` (web `MealCard`) keeps its name rule **only** for meals none of
  whose entries carry a tag — i.e. unbackfilled leftovers. It is retired the
  moment such meals stop mattering; this plan does not delete it.
- Rejected: keeping both rules in usage. A meal that is tagged *and* named would
  count twice or need dedup logic; one source of truth is easier to test.

### 2.6 Backfill: only unambiguous names, and the meal's `updated_at` is bumped

`V95` tags `meal_entries` of a non-deleted meal whose `name` equals
(`lower(btrim(...))`) the name of **exactly one** live recipe of the same user.
Ambiguous or unmatched names stay untagged. The migration then sets
`meals.updated_at = now()` for every meal it touched.

The bump is not decoration: clients page the delta feed by `updated_at`
(`findByUserIdAndUpdatedAtGreaterThanEqual`); raw SQL does not run JPA's
`@PreUpdate`, so without it no phone or web session would ever receive the
tags (flyway-migration skill §5).

- Known wrinkle: a mobile edit of a named meal keeps the name while letting the
  user add foods (docs/87 §2.6 edge case), so the backfill can tag a few
  non-recipe foods in such a meal. Accepted: it only affects counts and a
  group header on a handful of rows, and the app is not released.

### 2.7 Mobile: the local column has no foreign key, and the push reference is optional

- `meal_entries.recipe_client_id` is a plain nullable text column, **not**
  `references(Recipes, #clientId)` like `foodClientId`: recipes are removed
  locally when deleted, and a dangling id must degrade to "not grouped", not
  violate a constraint. The UI treats an unknown recipe id as an untagged entry.
- The outbox payload sends `recipeId: optionalClientRef(recipeClientId)`
  (new, M1). Today a `clientRef` that cannot be resolved *fails the operation
  for good* (`_resolvePayload` throws `Unresolved clientRef`; the op is parked
  failed). That is right for a food (an entry cannot exist without it) but wrong
  for a tag: deleting a never-synced recipe while a meal that used it waits in
  the outbox would lose the whole meal. `optionalClientRef` resolves to `null`
  when the row is gone and nothing is pending for it; if the recipe's own
  create is still queued, the meal waits for it like for any dependency
  (`outbox_dependencies.dart`).
- Pull: `_upsertMeal` resolves `entry['recipeId']` through
  `_localClientId('recipes', id)`. Recipes are pulled before meals
  (`pull_engine.dart`, `_pullRecipes` precedes `_pullMeals`), so the local row
  exists; if it does not, store null.

### 2.8 Grouping is a display rule over tags: first-appearance position, one group per recipe per meal

A group is "all entries of this meal sharing a `recipeId`", rendered at the
position of its first entry, header = the recipe's **current** name
(`recipeName` on the API, the local recipe's name on mobile), amount = sum of
its entries. Untagged entries render as today.

- Rejected: relying on adjacency (consecutive tagged rows). Entries have no
  guaranteed order across edits and sync.
- Group header's delete removes every entry of the group; deleting one row
  removes just that row.
- Web `MealCard` shows a group as **one collapsed row** (as it does today for a
  recipe-named meal); the edit drawer lists the individual entries. Mobile's
  `LogMealScreen` is an editor, so it shows the header plus indented rows.

### 2.9 Trainer and other readers get the name for free

`MealResponse` is also what the trainer's client-nutrition view and the delta
feed return. `recipeName` is denormalised into the entry response so a reader
that does not own the recipe (the trainer) can still say "Chilli". Rendering
it there is a non-goal; the field costs nothing.

## 3. Spec

### 3.1 Backend

`backend/src/main/resources/db/migration/V95__meal_entry_recipe.sql` (V94 is the
current highest; do not fill any gap):

```sql
-- Which recipe a meal entry came from (docs/88 §2.1). Nullable: entries from
-- foods, macros and photo estimates have none; a deleted recipe leaves null.
alter table meal_entries
    add column recipe_id bigint references recipes (id) on delete set null;
create index meal_entries_recipe_id_idx on meal_entries (recipe_id);

-- Backfill (docs/88 §2.6): entries of a live meal named exactly like ONE live
-- recipe of the same user. Raw SQL does not fire @PreUpdate, so the touched
-- meals' updated_at is bumped explicitly or no client ever pulls the tags.
with unique_names as (
    select user_id, lower(btrim(name)) as n, min(id) as recipe_id
      from recipes
     where deleted_at is null
     group by user_id, lower(btrim(name))
    having count(*) = 1
), tagged as (
    update meal_entries e
       set recipe_id = u.recipe_id
      from meals m
      join unique_names u on u.user_id = m.user_id and u.n = lower(btrim(m.name))
     where e.meal_id = m.id and m.deleted_at is null and m.name is not null
    returning e.meal_id
)
update meals set updated_at = now() where id in (select meal_id from tagged);
```

- `MealEntry`: `@ManyToOne(fetch = LAZY) @JoinColumn(name = "recipe_id") Recipe recipe;`
- `MealEntryRequest`: `Long recipeId` (nullable, no validation annotation).
- `MealEntryResponse`: `Long recipeId, String recipeName` appended to the
  record; the existing 7-argument convenience constructor keeps working
  (`null, null`). `MealMapper` fills them from `entry.getRecipe()`.
- `MealServiceImpl.replaceEntries`: resolve `recipeId` per 2.4.
- `MealRepository` queries that already fetch `entries → food` also fetch the
  recipe, so the mapper's `getRecipe().getName()` is not an N+1.

### 3.2 Mobile

| Piece | Change |
|---|---|
| `core/sync/client_ref.dart` | `optionalClientRef(id)`, `isOptionalClientRef`, shared id extraction (M1) |
| `core/sync/sync_engine.dart` | `_resolvePayload` → `null` for an unresolvable optional ref; `_hasUnresolvedRefs` waits only while a pending op exists for it (M1) |
| `core/sync/outbox_dependencies.dart` | collects optional refs as dependencies (M1) |
| `core/local_db/tables/meal_tables.dart` | `TextColumn get recipeClientId => text().nullable()();` on `MealEntries` (M2) |
| `core/local_db/app_database.dart` | `schemaVersion` 52 → 53; `if (from < 53) await _addColumnIfMissing(m, mealEntries, mealEntries.recipeClientId);`; `dart run build_runner build --delete-conflicting-outputs` (M2) |
| `features/nutrition/domain/meal.dart` | `MealEntry.recipeClientId` (M2) |
| `features/nutrition/data/meal_repository.dart` | `MealEntryInput.recipeClientId`; `_insertEntries`, `_payload`, `_processJoined` carry it; `watchRecipeUsage()` (M2, M4) |
| `features/nutrition/application/meal_controller.dart` | `duplicateMeal`, `copyMeals` pass `recipeClientId` (M2) |
| `core/sync/pull_engine.dart` | `_upsertMeal` resolves `recipeId` (M2) |
| `log_meal_screen.dart` | `_entries` record gains `recipeClientId`; initState from `meal.entries`, `_editEntry`, `_persist` carry it; add-recipe and recipe-sheet tag (M3); grouped list (M5) |
| `features/recipes/.../log_recipe_sheet.dart` | tags its entries (M3) |
| `add_recipe_sheet.dart` (docs/87) | list ordering from `recipeUsageProvider` (M4) |

### 3.3 Web

| Piece | Change |
|---|---|
| `features/nutrition/types.ts` | `MealEntryResponse.recipeId?/recipeName?: … \| null`, `MealEntryRequest.recipeId?: number \| null` (W1) |
| new `entryRequestOf(e: MealEntryResponse): MealEntryRequest` | the **only** place a response entry becomes a request entry; used by `mealEdit.ts`, `copyMeal.ts`, `copyFromDay.ts`, `mealMerge.ts` / `FoodPreviewPane`, `EditMealDrawer`, `useCopyMeals.ts` (W1) |
| `logRecipePortion.ts` | `buildEntries(..., recipeId?)` stamps (W2) |
| `LogRecipeDialog.tsx`, `FoodPreviewPane.tsx` | pass `recipe.id` (W2) |
| `usage.ts` | `computeRecipeUsage` from `recipeId` (W2) |
| `MealCard.tsx` | `mealItemRows` groups by `recipeId` (W3) |

## 4. Order of work

### 4.1 Milestones

| Milestone | Demo | Steps |
|---|---|---|
| **Tag** | Nothing new on screen; in the DB, an API response and a mobile pull, a meal's entries carry `recipeId`/`recipeName`, an edit from either client keeps them, an old recipe-named meal got tagged by the migration | B1, B2, M1, M2, W1 |
| **Use** | Add a recipe + a food to one meal on either client → the recipe is in "Recent" (web) / first in the picker (mobile); rename the recipe → still counted | M3, M4, W2 |
| **Show** | The meal shows "Chilli" as one group beside the salad (web card, mobile editor) | M5, W3 |

**Smallest thing worth using: Tag + Use on one platform** (W2 on web; M3 + M4
on mobile). Grouped display (Show) is the polish.

### 4.2 Suggested PR split

One branch + PR per Jira ticket. Backend lands first and alone (B1, then B2),
because both clients depend on the field. M1 is independent of the backend and
can be reviewed any time. Mobile and web never share a PR. The Tag milestone
changes no visible behaviour, so it can be merged and soaked before the Use
steps.

## Prompt B1 — Backend: `V95__meal_entry_recipe.sql`, entity, backfill (LIF-167)

Per §3.1: migration, `MealEntry.recipe`. No DTO or service change yet.

Verify: `./devops/check-schema-ownership.sh && cd backend && ./mvnw -B verify`
(Docker running). New migration test seeding one user with: a meal named like a
unique live recipe (tagged afterwards); a meal named like a recipe that has a
second live recipe of the same name (untagged); a meal named like a *deleted*
recipe (untagged); a plain unnamed meal (untagged); a second user's identically
named recipe (not used). Assert the tagged meal's `updated_at` moved and the
others' did not.

## Prompt B2 — Backend: `recipeId` / `recipeName` in the meal API (LIF-168)

Request/response fields, service resolution (2.4), mapper, fetch joins (§3.1).
Update the Postman collection for the changed meal request/response.

Verify: service and controller tests — create with a tagged entry returns
`recipeId` + `recipeName`; update **without** `recipeId` clears it (pin the
contract); a soft-deleted own recipe is accepted; another user's recipe → 404;
the delta feed (`/meals?updatedSince=`) includes the fields; an entry-only tag
change bumps `updatedAt`. A query-count assertion (or Hibernate statistics) on
`findAll` with N tagged entries shows no per-entry recipe query.

## Prompt M1 — Mobile sync: optional `clientRef` (LIF-169)

Per 2.7. `optionalClientRef` resolves to `null` for a vanished referent and
defers while its operation is pending; plain `clientRef` behaviour is
untouched. No caller yet.

Verify: `sync_engine` / `outbox_dependencies` tests — referent synced (id
substituted); referent unsynced with a pending create (meal waits, then id);
referent row gone and nothing pending (field becomes `null`, operation
succeeds); a *plain* unresolvable `clientRef` still fails exactly as before.
`flutter test test/core/sync`.

## Prompt M2 — Mobile data: carry `recipe_client_id` locally, push and pull (LIF-170)

Per §3.2 (column, version 53, domain, repository, controller, pull). Includes
`duplicateMeal` and `copyMeals`. Nothing in the UI sets a tag yet.

Verify: repository tests — insert with a tag, read it back in `_processJoined`;
`update` keeps tags passed in; `_payload` contains `recipeId` as an optional ref
and omits it for untagged entries; `duplicateMeal`/`copyMeals` preserve tags.
Pull test — a meal JSON with `recipeId` of a locally known recipe stores its
client id; an unknown recipe id stores null; replacing entries on a second pull
keeps the tag. Migration test v52 → v53 on an existing database file.
`flutter test`, `flutter analyze`, `build_runner` produced no hand edits.

## Prompt M3 — Mobile UI: recipe paths set the tag (LIF-171)

`LogRecipeSheet` and docs/87's `AddRecipeSheet` set `recipeClientId` on the
entries they produce; `LogMealScreen`'s `_entries` carries it through
`initState` (editing an existing meal), `_editEntry` and `_persist`. Needs
docs/87 M3 (LIF-161) for the Add-recipe half.

Verify: widget tests — add a recipe then a food → saved inputs: recipe rows
tagged, food not; edit one recipe row's grams → still tagged; reopen a saved
meal for editing → tags intact; Recipes-tab log → all rows tagged. Emulator:
log a mixed meal, force a pull (or reinstall + login), the same meal reopens
with tags (check via a debug query or the grouped display once M5 lands).

## Prompt M4 — Mobile data: recipe usage and picker ordering (LIF-172)

`MealRepository.watchRecipeUsage()` → `Map<String recipeClientId, RecipeUsage>`
(last used, count; once per meal per recipe; 90-day window; same shape as
`watchFoodUsage`), `recipeUsageProvider`; the picker's order: last used, then
favourites, then A–Z.

Verify: repository test (a meal with two tagged rows of one recipe counts once;
a copied meal counts as another use; a meal outside 90 days does not); widget
test on the picker order.

## Prompt M5 — Mobile UI: recipe group in the meal editor (LIF-173)

Per 2.8: group header (name from the local recipe, total kcal), indented rows,
header menu "Remove recipe" removing the whole group, untagged rows unchanged;
a tagged entry whose recipe is unknown locally renders as a loose row.

Verify: widget tests (group + loose food; remove group; unknown recipe → loose;
two recipes → two groups). Emulator: 360 dp, 130 % font scale, Hungarian.
`dart run tool/design_audit.dart --strict` (from `mobile/`).

## Prompt W1 — Web: `recipeId` through every existing meal writer (LIF-174)

Types and `entryRequestOf` per §3.3; replace each hand-rolled
`{ foodId, quantityInGrams }` mapping with it. Nothing *sets* a tag yet. Needs
B2 deployed locally.

Verify: extend the existing tests (`mealEdit.test.ts`, `copyMeal.test.ts`,
`copyFromDay.test.ts`, and docs/87's `mealMerge.test.ts`) with a tagged entry
that must come out tagged; `npm test`, lint, `npx tsc --noEmit`. In the browser
against the real backend: edit the grams of a backfilled recipe meal's row,
re-fetch `/meals` — `recipeId` still set (this is the test that proves the
silent-loss risk is closed). Also check by `grep -rn "quantityInGrams:" web/src`
that no other builder remains.

## Prompt W2 — Web: stamping and tag-derived usage (LIF-175)

`buildEntries(ingredients, divisor, overrides, recipeId?)`; `LogRecipeDialog`
and the Add-food recipe branch (docs/87 W2) pass `recipe.id`;
`computeRecipeUsage(meals)` per 2.5 — the `recipes` parameter and the name map
go away, its callers (`AddFoodModal`, any "recent" list) are updated.

Verify: `usage.test.ts` — mixed meal counts once per recipe; two recipes in one
meal count each; a renamed recipe keeps its count; entries older than 90 days
do not count; an untagged named meal does **not** count. Browser: add a recipe
and a food to Lunch → Add food → "Recent" filter lists the recipe; rename it on
the Recipes tab → still listed.

## Prompt W3 — Web: recipe group row on the meal card (LIF-176)

`mealItemRows` per 2.8 and 2.5's legacy note; group-row delete removes all of
the group's entries through the existing "delete item(s)" path with a
confirmation naming the recipe and the count.

Verify: `MealCard`/`mealItemRows` unit test (group + loose food, two recipes,
all-untagged named legacy meal still one row, all-untagged unnamed meal lists
foods); browser: the mixed Lunch card shows "Chilli" as one row and the salad
as another; the edit drawer still lists every ingredient; dark theme; Hungarian.

## 5. After implementation

- `Status:` here per milestone; update the `88` row in `docs/README.md`.
- In docs/87: replace the "Remembering which recipe the rows came from"
  non-goal with a pointer to this plan; its risk "Name-keyed recipe usage"
  becomes resolved once W2 lands.
- Close LIF-166 when LIF-167 … LIF-176 are done (it is only the umbrella).

## Non-goals (deferred)

- **Servings eaten as a number on a group** ("1.5 servings of chilli") —
  derivable later from grams or a new column (2.1).
- **"Detach from recipe" / re-tag an entry** (2.2).
- **Showing the recipe in trainer views** — `recipeName` is in the payload; the
  trainer UI does not use it yet.
- **Recipe-based statistics** (most-eaten recipes, per-recipe calories over
  time) — now possible, not asked for.
- **Removing `meals.name` or `isRecipeMeal`** — kept for untagged legacy meals
  and for the Recipes-tab "Log" flow's meal title; a separate clean-up once no
  untagged named meal remains.
- **Chat result card / AI estimation** carrying a recipe tag — they create
  untagged entries.
- Any change to the foods or recipes APIs.

## Edge cases

- **Recipe deleted (soft) on the server, meal then synced from an offline
  phone.** Accepted (2.4); the tag points at a deleted recipe. Usage ignores
  deleted recipes' rows by joining against live recipes in the UI; the group
  header uses `recipeName` as returned.
- **Recipe deleted locally before its meal synced** (never synced, or synced).
  M1's optional ref → `null`; the meal syncs untagged, no failed operation.
- **Recipe renamed after logging.** Tag unaffected; the header shows the new
  name (live), usage unaffected — the point of 2.5.
- **Recipe edited after logging** (ingredients changed). Entries are snapshots
  of grams of foods; the group does not change. Intended.
- **Same food in the recipe group and as a loose entry** (rice from the recipe
  plus rice added by hand). Two rows, one tagged, one not; never merged.
- **Duplicate / copy-day of a meal.** Tags copied — eating it again is another
  use of the recipe (2.5, M4 test).
- **Trainer-assigned recipe.** A normal recipe of the client; tags work the
  same.
- **Old client without the field** — unreleased app, so no compatibility
  window (see memory: app not released); but the contract in 2.3 means such a
  client would silently strip tags on edit. Not a supported configuration.
- **Meal with every tagged entry removed.** No group, nothing special; an empty
  meal is not persisted (existing rule).
- **Backfilled meal later edited on mobile** — the local row was updated by the
  pull (`updated_at` bumped by B1) before the user edits; if the user edits
  *before* the pull, the push is rejected by the pending-op guard in
  `_upsertMeal` and wins over the server tag (the push replaces entries with
  untagged ones). Rare and self-limiting (docs/16 pull rules); noted, not
  handled.

## Test plan

| Layer | What | Where |
|---|---|---|
| Backend migration | backfill cases + `updated_at` bump | new migration test next to `FoodsExercisesOwnershipMigrationTest` |
| Backend service/controller | tag round trip, clear-on-absent, soft-deleted ok, foreign 404, delta feed, no N+1 | `MealServiceImplTest`, controller test |
| Mobile unit | `optionalClientRef` in the sync engine and dependencies | `test/core/sync/*` |
| Mobile repository / pull / migration | tag persisted, pushed, pulled, preserved by duplicate/copy; v52→v53 | `meal_repository_test`, `pull_engine_test`, migration test |
| Mobile widget | recipe paths tag, edit keeps tag, picker order, grouped editor | M3–M5 tests |
| Web unit | `entryRequestOf` users, `buildEntries` stamp, `computeRecipeUsage`, `mealItemRows` | `*.test.ts` |
| Web manual (real backend) | edit keeps tag (API re-fetch), usage after rename, grouped card, dark, hu | W1–W3 |
| Cross-client | log on one client, edit on the other, tags survive both ways | manual, emulator + browser against one backend |

## Risk checkpoints where a failure would be silent

- **A writer that rebuilds entries without `recipeId`.** Every save from such a
  path erases provenance with no error and no visible change until a count or a
  group is missing weeks later. This is the dominant risk. Mitigations: one
  `entryRequestOf` on web (W1), a repo-wide `grep` for hand-rolled entry
  mappings in the PR description, a backend contract test pinning
  "absent ⇒ cleared" so the behaviour is at least deliberate, and the
  cross-client manual test (edit on web, pull on mobile, edit on mobile, pull
  on web).
- **Backfill without the `updated_at` bump.** The tags exist in the table but
  never reach a single client; usage on a fresh install is right and on an
  existing install is wrong. Test both the tags *and* the bump.
- **Backfill tagging the wrong recipe.** Name collisions across a user's
  recipes, or a deleted recipe sharing a name with a live one. The
  `having count(*) = 1` over *live* recipes is what prevents it; the migration
  test must include the duplicate-name and deleted-recipe cases.
- **Recipe usage counted per entry instead of per meal.** A six-ingredient
  recipe would count six uses. Both `computeRecipeUsage` and `watchRecipeUsage`
  need a test with several tagged entries in one meal.
- **A failed meal sync from a vanished recipe.** If a payload ever uses plain
  `clientRef` for the tag, deleting a recipe offline parks the meal's sync as
  failed and the meal never reaches the server. M1's test of the plain-ref
  failure *and* the optional-ref success is the guard.
- **N+1 on the meal list.** `recipeName` is read per entry; a missed fetch join
  turns `GET /meals` (all meals, unpaged) into hundreds of queries and still
  returns the right JSON.
- **Group header uses a stale name.** Mobile must read the recipe's name from
  the local recipes table at render time, not store it on the entry; otherwise
  a rename shows two different names on two screens.
