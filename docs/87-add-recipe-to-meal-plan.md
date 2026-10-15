# 87 – Add a Recipe to a Meal

Status: built — LIF-159 … LIF-165 merged on 2026-10-15 (epic LIF-6). Web path walked in a browser against the real backend
(Recipe mode, ingredient overrides, one Lunch with a food and a recipe, the Recipes tab's Log unchanged); mobile
checked in widget tests (360/411 dp, text ×1.3, Hungarian) and on the Pixel_10 emulator (2×2 action grid, the
recipe group, 130 % font scale). Recipe provenance on the entries followed in docs/88.
Scope: mobile · web — no backend, no schema change
Depends on: docs/75-log-food-from-foods-tab-plan.md (the meal-add flow this extends),
docs/redesign-web/78-web-redesign-plan.md W2.5/W2.6 (the web Add-food dialog),
docs/84-off-name-search-plan.md (the dialog's search pane)

Today a recipe can only be logged **as a meal of its own**: Recipes tab →
"Log" → pick type and portion → one meal named after the recipe. On the screens
where the user *builds* a meal the choice is narrower than it looks:

- **Mobile `LogMealScreen`**: three tiles — *Add food*, *Macros only*, *From
  photo*. There is no way to put a recipe into the meal being built, so a
  chilli plus a side salad is two meals.
- **Web Add-food dialog**: modes *Search* and *Enter macros*. Recipes are
  hidden among the search results (there is a "Recipes" filter chip), and
  picking one creates a separate meal named after the recipe — again, never
  one meal with the salad.

This plan adds **"Add recipe"** as a first-class third way to add to a meal on
both platforms: pick a recipe, say how much of it was eaten, optionally correct
individual ingredient amounts, and its ingredients become ordinary entries of
the meal, next to whatever else is in it.

## 1. What we're building

1. **Mobile — Add recipe tile.** `LogMealScreen`'s action row becomes a 2×2
   grid: *Add food*, *Add recipe*, *Macros only*, *From photo*. *Add recipe*
   opens a sheet: choose a recipe (search, favourites first), then the portion
   sheet — servings eaten, "Adjust ingredients" (collapsed), macro preview —
   and "Add".
2. **Mobile — result.** The recipe's ingredients appear as normal food rows in
   the meal (each editable / removable on its own), the footer summary updates,
   and the meal auto-saves like any other change. Foods, macros and photo
   estimates can be mixed into the same meal before or after.
3. **Web — Recipe mode.** The Add-food dialog's mode switch gets a third
   segment, **Recipe**: the left pane lists only recipes, the right pane is the
   recipe preview (servings eaten, meal type, macro tiles, "Adjust ingredients",
   "Left after this"), submit says "Add to Lunch".
4. **Web — result.** The ingredients go into the day's meal of the chosen type,
   exactly like a food does today (the latest plain meal of that type, else a
   new one). The same applies to a recipe row picked in *Search* mode — it no
   longer creates a separate named meal.
5. **When the feature is not used**, nothing changes: *Log* on a recipe card
   (mobile `LogRecipeSheet`, web `LogRecipeDialog`) still logs the whole recipe
   as its own meal named after it; food search, macros mode, photo estimate and
   meal editing behave as before.

## 2. Key design decisions

### 2.1 A recipe becomes its ingredients — no new meal-entry type

An added recipe is expanded into one meal entry per ingredient
(`{food, grams}` scaled to the portion), the same shape every other entry has.

- Rejected: a "recipe entry" (one row with the recipe's name and total
  macros). It needs a backend entry type, a migration, a sync shape and a
  display for it on four surfaces, and the trainer views, copy-meal, edit and
  the AI chat card would all need to learn it. Ingredient entries work
  everywhere today because they *are* the existing thing — which is also how
  `LogRecipeSheet` / `LogRecipeDialog` already log a recipe.
- Consequence: the meal does not remember *which recipe* the rows came from;
  see 2.6 and the follow-up LIF-166.

### 2.2 The amount is "servings eaten"; `RecipePortion` works on a divisor of the whole recipe

Both new surfaces ask *how many servings did you eat* (default 1, step 0.5,
0.25–50) — the question the web preview pane already asks. Internally the
portion is one number, the **divisor** of the whole recipe
(`recipe.servings / servingsEaten`, null = the whole recipe as stored) — the
same representation the web uses (`servings / qty`). `LogRecipeSheet`'s
existing "divide into N parts" is the same number (`N`, or null when not
split).

- Rejected: reusing the divisor UI on the new surfaces ("split into 4 parts").
  It answers the same question backwards and needs the "log as part meal"
  switch; "I ate 1.5 servings" is one field.
- Rejected: leaving the math duplicated in the two sheets. M1 extracts it to
  `mobile/lib/features/recipes/domain/recipe_portion.dart` so both share one
  rounding rule (grams to 2 decimals, per ingredient). The web already has the
  shared pure module `logRecipePortion.ts`; it is reused as is
  (`divisor = recipe.servings / qty`, as `FoodPreviewPane` does today).

### 2.3 Per-ingredient overrides are available but collapsed

"Adjust ingredients" (collapsed by default) lists each ingredient with an
editable amount for *what was eaten*; 0 leaves the ingredient out, a reset
button restores the computed default, and an override survives changing the
servings. This is the behaviour of `LogRecipeSheet` / `LogRecipeDialog`
(web `IngredientAmounts` is extracted from the dialog in W3 so the two
screens share it).

- Rejected: omitting overrides on the new surfaces. The recipe is typically
  not eaten to the gram; without overrides the user would add the recipe and
  then edit rows one by one on mobile, or could not on web at all.

### 2.4 Mobile: the recipe sheet returns drafts; `LogMealScreen` stays the single owner of the meal

`AddRecipeSheet` returns `List<MealEntryDraft>` (`({Food food, double grams})`
is the typedef the food sheet already returns). It never writes a meal; the
screen appends the drafts to `_entries` and calls `_autoSave()`, as for a
photo estimate (`_estimateFromPhoto`).

- The `Food` of each draft is rebuilt from the recipe ingredient's own figures
  (per-100 g = figure ÷ quantity × 100), exactly as `LogMealScreen.initState`
  already does when it opens an existing meal's entries. `_persist` only needs
  `food.clientId`; the screen's totals only need the per-100 g values. No
  repository lookup, so it works offline and for trainer-assigned recipes.
- Rejected: the sheet logging the meal itself (as `LogRecipeSheet` does). The
  point is to compose with other entries, and a second writer would race the
  screen's auto-save.

### 2.5 Mobile: four tiles are a 2×2 grid, not one row of four

The three tiles share one `IntrinsicHeight` row and already clamp text scale to
115 % so a Hungarian label does not break mid-word. A fourth tile in that row
would be ~80 dp wide on a 360 dp screen.

- Chosen: two rows of two, same `_ActionTile`, same clamp. Order: *Add food*,
  *Add recipe* (the two "pick from my stuff" actions) over *Macros only*,
  *From photo*.
- Rejected: a fourth narrow tile; moving *Macros only* / *From photo* into a
  menu (hides actions that exist today and are used).

### 2.6 Meal name: a recipe-only meal keeps the recipe's name, a mixed meal has none

`Meal.name` is today set only when a whole recipe is logged from the Recipes
tab, and the web `MealCard` and `computeRecipeUsage` read it. On mobile:

| Meal content | `name` |
|---|---|
| Only one recipe added (rows may be edited / removed afterwards) | the recipe's name |
| Anything else added too — a food, macros, photo items, a second recipe | `null` |
| Existing meal opened for editing | unchanged (as `_persist` does today) |

Implemented as `_recipeName` on the screen state: set when a recipe is added to
a still-empty new meal, cleared by any other add. The name is passed to
`logMeal` / `updateMeal`.

- Rejected: always `null` for recipes added here. A user who adds only a recipe
  would get a different result than from the Recipes tab for no reason they can
  see.
- Rejected: naming mixed meals "Chilli + …". Meal names are not free text in
  the UI and would feed the web's name-keyed recipe usage with junk.
- Known cost: a mixed meal does not count as a use of the recipe — the follow-up
  LIF-166 (recipe provenance on entries) fixes it properly; this plan does not
  paper over it.

### 2.7 Web: ingredients land where foods land — `mealMerge.ts`

The Add-food dialog has no "current meal"; each add goes to the day's *latest
plain meal of the chosen type* (`name == null`), else starts one
(`FoodPreviewPane.addFoodEntry`). That function becomes a pure
`planMealWrite(dayMeals, mealType, entries, date)` in
`web/src/features/nutrition/mealMerge.ts` (W1, no behaviour change), and the
recipe branch of the mutation calls it with `buildEntries(...)` instead of
`mealApi.create({ name: recipe.name, … })` (W2).

- Rejected: a switch in the dialog "keep as its own recipe meal". Two outcomes
  from one button doubles the states to test; the Recipes tab already offers
  the own-meal flow.
- Rejected: leaving search-row recipes as named meals while Recipe mode merges.
  Two different results for the same recipe in the same dialog is the kind of
  surprise this plan exists to remove.
- A named meal (a recipe logged from the Recipes tab) is still never extended
  with loose rows — that rule is unchanged.

### 2.8 Web: Recipe mode is Search with the data narrowed, not a third pane

`AddFoodMode` becomes `"search" | "recipe" | "macros"`. In `recipe` mode
`AddFoodModalView` passes `FoodSearchPane` only the recipe items and hides the
filter row; the right-hand pane is the existing recipe branch of
`FoodPreviewPaneView` (servings, chips, meal type, tiles, left-after). No new
pane component.

- Rejected: a separate recipe dialog. It would duplicate the meal-type chips,
  the remaining-budget block and the keep-open-after-add behaviour.

### 2.9 No backend change

Both clients already create and update meals from `{foodId | foodClientId,
grams}` plus an optional `name`. The meal API, sync and pull are untouched.

## 3. UI spec

### 3.1 Mobile — `log_meal_screen.dart`

- Action area (today `IntrinsicHeight` → `Row` of three `_ActionTile`s,
  lines ~491–529) becomes a `Column` of two such rows with `AppSpacing.s8`
  between them. New tile: `icon: Icons.menu_book_outlined`,
  `label: l10n.mealActionRecipe`, `background: p.primaryTint` like *Add food*,
  `onTap: _addRecipe`.
- `_addRecipe()`: `showModalBottomSheet<AddRecipeResult>(useRootNavigator: true,
  isScrollControlled: true, showDragHandle: true, …)` (same
  `// design-audit: ok` justification as the siblings); on a non-empty result,
  `_recipeName = _entries.isEmpty && !_isEditing ? recipe.name : null`, add the
  drafts, `_autoSave()`.
- Every other add path (`_addEntry`, `_addMacros`, photo) sets
  `_recipeName = null`. `_persist` passes `name: _recipeName` to `logMeal`
  (`widget.meal?.name` stays for `updateMeal` when editing).

### 3.2 Mobile — new `widgets/add_recipe_sheet.dart`

- Step 1 (picker): search `TextField` (name contains, case/diacritics-insensitive
  like the foods search), list of `recipeControllerProvider` recipes — favourites
  first, then A–Z — each row: name, "{n} ingredients · {kcal} kcal / serving".
  Empty list → "No recipes yet" with no action (creating recipes stays in the
  Recipes tab). A recipe with no ingredients is listed but disabled.
- Step 2 (portion): servings field (decimal, step 0.5), the "Adjust ingredients"
  toggle with the per-ingredient rows from `LogRecipeSheet` (`_ingredientRow`
  moves to a shared widget in M2), macro preview line + `FiberSugarLine`, "Add"
  disabled while every ingredient is 0 g. Back returns to the picker.
- Returns `AddRecipeResult = ({Recipe recipe, List<MealEntryDraft> drafts})`.

### 3.3 Mobile — `recipe_portion.dart` (M1)

```dart
class RecipePortion {
  const RecipePortion(this.recipe, {double? divisor, Map<int, double> overrides = const {}});
  double defaultGramsFor(int i);             // round2(quantity / divisor); as stored when divisor is null
  double gramsFor(int i);                    // override ?? defaultGramsFor(i)
  double get calories / protein / carbs / fat;
  FiberSugarTotals get fiberSugar;
  bool get hasLoggableEntry;
  List<PortionIngredient> get loggable;     // (ingredient, grams), 0 g left out
}
// plus extension RecipeIngredientFood.toFood(): the ingredient as a Food with per-100 g figures
```

`LogRecipeSheet` is refactored onto it in M1 with no visible change.

### 3.4 Web — `AddFoodModal.tsx`, `FoodPreviewPane.tsx`

- `AddFoodMode = "search" | "recipe" | "macros"`; the `SegmentedControl` gets
  `{ value: "recipe", label: t("modeRecipe"), icon: "menu_book" }` between the
  other two. In recipe mode `results` is `items.filter(kind === "recipe")`, no
  filter row, no OpenFoodFacts checkbox, empty state "No recipes yet".
- `FoodPreviewPane`: recipe branch calls
  `planMealWrite(dayMeals, mealType, buildEntries(recipe.ingredients, servings / qty, overrides), date)`;
  the `IngredientAmounts` block (W3) sits under the quantity row, collapsed.
  The preview tiles and "left after" read `scaledMacros(..., overrides, foodsById)`.
- Strings in `web/messages/en.json` + `hu.json`:
  `nutrition.addFoodModal.modeRecipe` ("Recipe" / "Recept"),
  `…recipeEmpty` ("No recipes yet" / "Még nincs receptje"),
  `…adjustIngredients` (reuse `nutrition.logRecipeDialog.adjustIngredients`).

### 3.5 Strings (mobile ARB, via the `localization` skill — both files)

| Key | en | hu |
|---|---|---|
| `mealActionRecipe` | Add recipe | Recept hozzáadása |
| `addRecipeSheetTitle` | Add a recipe | Recept hozzáadása |
| `addRecipeEmpty` | No recipes yet | Még nincs receptjed |
| `addRecipeNoMatch` | No recipe matches | Nincs ilyen recept |
| `addRecipeRowSubtitle` | {count} ingredients · {kcal} kcal / serving | {count} hozzávaló · {kcal} kcal / adag |
| `addRecipeServingsLabel` | Servings eaten | Elfogyasztott adag |
| `addRecipeServingsDecreaseTooltip` / `…IncreaseTooltip` | Fewer / More servings | Kevesebb / Több adag |
| `addRecipeConfirm` | Add to meal | Hozzáadás az étkezéshez |

The search field reuses `searchRecipesHint`. (`mealActionRecipe` arrives with
the tile in M3.)

The ingredient-adjust strings (`adjustIngredientsButton`, `ingredientAmountsHint`,
`resetIngredientTooltip`, `recipeMacrosPreviewLabel`) already exist and are reused.

## 4. Order of work

### 4.1 Milestones

| Milestone | Demo | Steps |
|---|---|---|
| **Mobile** | Log meal → *Add recipe* → pick "Chilli", 1.5 servings, trim the rice to 60 g → rows appear, then add a salad via *Add food* → one meal, one footer total | M1, M2, M3 (LIF-159/160/161) |
| **Web** | Add food → *Recipe* tab → pick the recipe → "Add to Lunch"; add a food → Meals tab shows **one** Lunch with both | W1–W4 (LIF-162/163/164/165) |

The mobile milestone is independent of the web one and either can land first.
**Smallest thing worth using: M3 on mobile, or W2 on web** (recipes already
findable in Search, and they now join the meal); everything after is polish.

### 4.2 Suggested PR split

One branch + PR per Jira ticket (house rule): M1 → M2 → M3 in order on mobile;
W1 → W2 → W3 → W4 on web. M1 and W1 are pure refactors and can be reviewed
for "nothing changed" alone. The two platforms never share a PR.

## Prompt M1 — Mobile data: extract `RecipePortion` from `LogRecipeSheet` (LIF-159)

Create `recipe_portion.dart` per §3.3 and move the scaling, rounding, override
and macro-sum logic out of `_LogRecipeSheetState`
(`_effectiveGrams`, `_gramsFor`, `_scaledTotal`, `_scaledFiberSugar`,
`_hasLoggableEntry`, the entry building in `_submit`). The sheet keeps its UI
state (divisor, text controllers) and builds a `RecipePortion` from it.

Verify: new `recipe_portion_test.dart` — rounding to 2 decimals, divisors 1 /
3 / 4 ÷ 1.5, override beats default, override 0 drops the row, an ingredient with
`quantityInGrams == 0` contributes nothing and does not divide by zero, fibre /
sugar stay null when no ingredient has a figure. `flutter test
test/features/recipes` (the existing `log_recipe_sheet_test.dart` must pass
untouched) and `flutter analyze`.

## Prompt M2 — Mobile UI: `AddRecipeSheet` (picker → portion) (LIF-160)

Per §3.2. Move `_ingredientRow` into a shared `ingredient_amount_row.dart`
used by both sheets. Strings via the `localization` skill. Not reachable from
anywhere yet.

Verify: `add_recipe_sheet_test.dart` — search narrows the list and ignores
case/accents; favourites sort first; empty state; a recipe without ingredients
is disabled; servings 2 doubles the drafts' grams; an override of 0 drops that
draft; all-zero disables "Add"; the returned drafts' grams equal what the
preview line is computed from; back from step 2 returns to the picker.

## Prompt M3 — Mobile UI: "Add recipe" tile on `LogMealScreen` (LIF-161)

Per §3.1 and §2.6. 2×2 grid, `_addRecipe`, `_recipeName`, name passed on save.

Verify: `log_meal_screen_add_recipe_test.dart` with an overridden
`mealControllerProvider` — tile → sheet → rows; `logMeal` called once with the
recipe's name; add a food afterwards → the next save carries `name: null`;
recipe added to a non-empty meal → `name: null`; editing an existing named
meal keeps its name; cancelling the sheet changes nothing and does **not** close
the screen. Emulator walk (see the emulator-adb workflow): small screen, 130 %
font scale (no mid-word wrap), Hungarian labels, offline add + sync.
`dart run tool/design_audit.dart --strict` (from `mobile/`) must be clean (no raw colours / sizes).

## Prompt W1 — Web logic: extract `planMealWrite` into `mealMerge.ts` (LIF-162)

Move the target-meal choice out of `FoodPreviewPane.addFoodEntry` per §2.7.
`FoodPreviewPane` calls it for foods, OpenFoodFacts items and macro entries.

Verify: `mealMerge.test.ts` — no meal of that type → `create` with the entries;
a plain meal exists → `update` carrying its old entries (as `{foodId,
quantityInGrams}`) then the new ones; two plain meals → the one with the later
`dateTime`; a *named* meal of that type is never the target; a plain meal of a
different type is never the target; the create timestamp comes from
`logTimestampFor(date)`. `npm test`, `npm run lint`, `npx tsc --noEmit`; in the
browser, adding two foods to Lunch still produces one Lunch.

## Prompt W2 — Web UI: a recipe from the Add-food dialog joins the meal (LIF-163)

Per §2.7: the recipe branch of the `add` mutation uses `planMealWrite` and
`buildEntries(recipe.ingredients, servings / qty, {})`; the named-meal create
is removed from this path. `LogRecipeDialog` is untouched.

Verify in the browser against the real backend: add a food to Lunch, then a
recipe (1 serving) → one Lunch, entries = food + the recipe's ingredients, day
total = sum; add the same recipe at 2 servings → ingredient grams doubled;
Recipes tab → *Log* still produces a separate named card. Unit check that
`buildEntries` at `servings / qty` matches the old behaviour (existing
`logRecipePortion.test.ts` stays green).

## Prompt W3 — Web UI: adjust ingredients in the recipe preview (LIF-164)

Extract the "Adjust ingredients" block of `LogRecipeModal` into
`IngredientAmounts.tsx` (props: ingredients, divisor, overrides, onChange);
`LogRecipeModal` uses it unchanged; `FoodPreviewPaneView` renders it for a
recipe row (state: `overrides`, reset when the highlighted row changes, as `qty`
already is) and feeds `scaledMacros` / `buildEntries`.

Verify in the browser: override one ingredient → tiles and "left after" move;
0 g drops it from the saved meal; changing servings keeps the override;
highlighting another recipe clears overrides; `LogRecipeDialog` looks and
behaves exactly as before. Extend `logRecipePortion.test.ts` only if a helper
changed.

## Prompt W4 — Web UI: "Recipe" mode in the Add-food dialog (LIF-165)

Per §2.8 and §3.4. Strings in `en.json` + `hu.json`.

Verify in the browser: segmented control shows Search · Recipe · Macros; Recipe
mode lists only recipes, Enter adds, the dialog stays open and resets for the
next add (existing behaviour); switching mode keeps the meal-type choice; dark
theme; below 768 px the dialog is the bottom sheet and the third segment still
fits; Hungarian labels.

## 5. After implementation

- Set `Status:` here per milestone; add row `87` to the table in
  `docs/README.md` and bump "currently up to".
- Update the "Log a food from the Foods tab" cross-reference only if the Add-food
  dialog's description there is now wrong (it already says superseded).
- Screenshots in each PR (light + dark; mobile at 360 dp and 130 % font).
- LIF-166 (recipe provenance on entries) has its own plan, docs/88; the
  stamping steps there (M3, W2) build on this plan's Add-recipe flows.

## Non-goals (deferred)

- **Remembering which recipe the rows came from** (built in docs/88) — recipe usage in mixed
  meals, a grouped "Chilli (1.5 servings)" block inside a meal, "log it again"
  at the same portion. Needs `recipe_id` on entries (migration, sync, both
  clients): LIF-166, planned in `docs/88-recipe-provenance-on-meal-entries-plan.md`.
- **Mobile "Add recipe" outside `LogMealScreen`** — the dashboard quick action,
  a "Add to meal" button on the recipe card (the recipes analogue of docs/75).
- **Adding to an existing meal from the web dialog by picking the meal** — it
  keeps using "latest plain meal of that type".
- **Recipe suggestions / recents in the picker** — mobile has no recipe usage
  stats; favourites + A–Z is enough for the first version.
- **Creating a recipe from inside the picker.**
- **Trainer views** (`ClientNutritionTab`) — they read meal entries, so recipe
  rows show up as foods with no change.
- Backend changes of any kind.

## Edge cases

- **Recipe with no ingredients.** Listed but disabled (mobile); on web "Add"
  stays disabled because `buildEntries` is empty (`canSubmit` must also check
  it — today it only checks `qty > 0`).
- **All ingredients overridden to 0 g.** Add disabled on both platforms; never
  an empty meal write.
- **Servings eaten far from the recipe's yield** (0.25 of a 1-serving recipe,
  or 50). Per-ingredient grams are rounded to 2 decimals and an ingredient that
  rounds to 0 is left out — tiny spices at 0.25 servings vanish. Intended, and
  the same as the Recipes-tab flow.
- **Same food twice in one meal** (recipe uses rice, user adds rice too). Two
  rows; entries are not merged. Verify the backend accepts duplicate `foodId`
  entries (the photo-estimate flow can already produce them) — check in M3 /
  W2 before relying on it.
- **Ingredient food deleted or not yet synced.** Mobile: the draft references
  `foodClientId`, the outbox sends the food before the meal (same as docs/75);
  a deleted food hits the existing 4xx path. Web: the ingredient's `foodId`
  comes from the server, so a deleted food cannot appear.
- **Mobile — recipe added, then every row removed by hand.** `_entries` is empty
  again; `_autoSave` writes nothing for an empty meal (existing rule). The stale
  `_recipeName` is cleared when the list becomes empty so the next add starts
  clean.
- **Mobile — editing an existing recipe-named meal and adding a food.** The name
  is kept (existing `updateMeal` behaviour); not made worse, not fixed here.
- **Mobile — trainer-assigned recipe** (`originTrainerId`). Treated like any
  recipe; the meal carries no "from trainer" mark.
- **Mobile — offline.** Recipes and their ingredient figures are local; nothing
  here needs the network.
- **Web — dialog stays open after an add.** The next add must see the meal the
  previous one wrote, so the mutation still awaits the `meals` invalidation
  (existing behaviour, see the comment in `FoodPreviewPane`).
- **Web — recipes still loading when Recipe mode opens.** Empty state must not
  flash "No recipes yet" while `recipeApi.list` is pending.

## Test plan

| Layer | What | Where |
|---|---|---|
| Mobile unit | `RecipePortion` scaling, rounding, overrides, zero handling | new `recipe_portion_test.dart` |
| Mobile widget | `AddRecipeSheet` flow, drafts equal preview | new `add_recipe_sheet_test.dart` |
| Mobile widget | `LogMealScreen` tile, entries, name rule, cancel | new `log_meal_screen_add_recipe_test.dart` |
| Mobile regression | Recipes-tab logging unchanged | existing `log_recipe_sheet_test.dart` |
| Mobile manual | emulator: small screen, large font, hu, offline | M3 verification |
| Web unit | `planMealWrite`; `buildEntries` at `servings / qty` | new `mealMerge.test.ts`, `logRecipePortion.test.ts` |
| Web manual (browser, real backend) | one meal with food + recipe, overrides, Recipe mode, dark, narrow, hu | W2–W4 verification |

The web has no component-test setup (docs/75), so dialog behaviour is verified
in the browser; the pure functions carry the unit tests.

## Risk checkpoints where a failure would be silent

- **Wrong grams from the divisor.** Both platforms divide the recipe by
  `recipe.servings / servingsEaten` (mobile `RecipePortion.divisor`, web
  `servings / qty`); flipping the fraction on either one logs a recipe at 1/n² or n² of what was eaten and every screen
  still looks plausible. The tests must pin a concrete case on each platform:
  a 4-serving recipe of 400 g flour at 1 serving logs **100 g**, at 2 servings
  **200 g**.
- **The preview and the saved entries disagree.** The macro tiles and the
  entries must come from the same `RecipePortion` / `buildEntries` call with
  the same overrides. Add a test that sums the saved entries and compares them
  to the preview.
- **Mobile name rule leaking.** If `_recipeName` is not cleared by the other
  add paths, a chilli + a pizza is saved as a meal named "Chilli" and the web
  shows it as a recipe meal with a recipe's badge. Check all three other add
  paths and the edit-existing path.
- **Web merge extending a named meal.** `planMealWrite` must keep the
  `name == null` filter; if it ever targets a recipe meal, a food gets appended
  to "Chilli" and its `name: null` update silently *renames* it away.
- **Web update drops entries.** The update payload must carry every existing
  entry as `{foodId, quantityInGrams}` before the new ones; a missed field
  deletes the meal's earlier rows without any error.
- **Per-100 g rebuilt from rounded figures (mobile).** Deriving `Food` per-100 g
  from `ingredient.calories / quantityInGrams * 100` and multiplying back by the
  grams must reproduce the recipe's own calories at the original grams; test at
  a non-round grams value.
- **Name-keyed recipe usage.** After W2 the web's recipe usage ("recent" /
  last-used) stops counting Add-food recipe adds. Intentional and tracked as
  LIF-166, but reviewers should expect the "Recent" filter to forget recipes
  added this way.
