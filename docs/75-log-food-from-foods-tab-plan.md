# 75 – Log a Food from the Foods Tab

Status: in progress — mobile done (Prompts 1–3 ✅); web implemented (Prompts 4–7), browser verification pending
Scope: mobile · web — no backend, no schema change
Depends on: docs/27-faster-meal-logging-plan.md (food usage stats, last-used
quantity prefill — already done on both platforms)

Today a food can only be logged from inside the meal flow: open "Log meal" →
"Add food" → search for the food → type the quantity. When the user is
*already looking at the food* in the Foods tab (browsing, just created it, just
scanned its barcode) they have to leave, re-find it by name, and pick it again.
This plan adds an "Add to meal" action on every food in the Foods tab that
lands the user in the normal meal-add flow with the **Add food to meal** popup
already open, the food filled in and the **quantity field focused** — exactly
the state they would reach after picking the food by hand.

## 1. What we're building

1. **Mobile — Foods tab:** each food card gets an "Add to meal" icon button.
   Tapping it opens `LogMealScreen` (new meal) and immediately opens
   `AddMealEntrySheet` on top of it, with the food pre-selected, the last-used
   quantity prefilled and selected, and the quantity field focused with the
   numeric keyboard up. Tapping the card body still opens the food editor.
2. **Mobile — confirm:** "Add" in the sheet adds the entry to the new meal,
   which auto-saves as it does today. The user stays on `LogMealScreen` and can
   change meal type / time, add more foods, or go back.
3. **Mobile — cancel:** dismissing the auto-opened sheet without adding closes
   `LogMealScreen` too and returns to the Foods tab. Nothing is saved.
4. **Web — Foods tab:** each row of the foods table gets an "Add to meal" icon
   button, and the food editor panel gets an "Add to meal" button for an
   existing food. Both open `AddMealEntryDialog` with the food already picked,
   the last-used quantity prefilled and the quantity input focused.
5. **Web — meal type & date:** because the Foods tab has no meal-type context,
   the dialog shows a meal-type selector (defaulting from the time of day) when
   opened from Foods. The date is the app-wide date from the top bar
   (`useDateStore`), the same one `RecipesView` → `LogRecipeDialog` uses.
6. **When the feature is not used**, every existing flow is unchanged: "Log
   meal" FAB, "Add to Breakfast" etc. on web, edit-entry mode, recents,
   prefill.

## 2. Key design decisions

### 2.1 Reuse the existing meal flow — no new "quick log" sheet

We open the **real** `LogMealScreen` / `AddMealEntryDialog` with the popup
pre-filled, rather than building a compact "log this food" sheet with its own
meal-type + date + grams fields.

- Rejected: a dedicated quick-log sheet. It would duplicate the meal-type
  picker, the date/time picker, the budget preview and the auto-save logic,
  and it would be one more place for the two platforms to drift apart. It also
  isn't what was asked for — the goal is to land in the meal-add window.
- Consequence: after confirming, the user sees the full meal screen and can add
  a second food with no extra navigation. That is a feature, not a cost.

### 2.2 "Pre-selected" is a third mode of the entry popup, distinct from edit mode

`AddMealEntrySheet` (mobile) already has two modes: *add* (search field
focused) and *edit* (`initialFood` + `initialGrams`, food field **locked**,
title "Edit food entry"). The new mode is *add with a pre-selected food*:

| | add | **add, pre-selected (new)** | edit |
|---|---|---|---|
| Title | Add food to meal | Add food to meal | Edit food entry |
| Food field | empty, focused | filled, **changeable** (clear ✕ works) | filled, read-only |
| Quantity | empty or prefill after pick | last-used grams prefilled + selected, **focused** | existing grams, focused |
| Recents row | shown | hidden | hidden |
| Button | Add | Add | Save |

- Mobile: new constructor parameter `preselectedFood`, asserted mutually
  exclusive with `initialFood`. We do **not** reuse `initialFood`, because that
  flips `_isEditing` and would lock the field, change the title and the button
  label, and subtract an "old" contribution in the budget preview that doesn't
  exist.
- Web: `SearchMode` gets an `initialPicked` food; it starts in its existing
  "picked" state (food chip + "Change" link + quantity input). The existing
  `useEffect` on `picked` already focuses and selects the quantity input, so
  focus comes for free.
- Recents are hidden in pre-selected mode: the user has already chosen, and on
  a phone the extra row pushes the budget preview under the keyboard.

### 2.3 Quantity prefill uses the usage stats, applied once, never over typed input

The prefill is the food's last-used grams from `foodUsageProvider` (mobile) /
`computeFoodUsage` (web) — the same source as docs/27 M2/W1. No usage → field
is empty (placeholder "100" on web) and still focused.

On mobile `foodUsageProvider` is a stream and may not have emitted when the
sheet's `initState` runs, so the prefill is applied **once, the first time
usage is available**, through the existing `_prefillGrams`, which already
refuses to overwrite a hand-typed value (`_gramsAutoFilled`). A flag
(`_preselectPrefillApplied`) stops it re-applying on later stream emissions.

### 2.4 Mobile: the sheet is opened by `LogMealScreen` itself, after its first frame

`LogMealScreen` gains an optional `initialFood`. When set, `initState`
schedules `_addEntry(preselected: initialFood, closeScreenOnCancel: true)` in
a post-frame callback.

- Rejected: the Foods tab opening the sheet first and pushing `LogMealScreen`
  with the resulting draft. That shows the popup over the Foods list, not "in
  the meal add window", and it needs a second code path for adding an entry to
  a not-yet-built screen.
- Rejected: the Foods tab pushing the screen and then opening the sheet over
  it. The tab would need a handle on the pushed route's state; the screen
  owning its own first action is simpler and testable in isolation.

### 2.5 Mobile: cancelling the auto-opened sheet closes the empty meal screen

If the sheet returns `null` **and** `_entries` is still empty **and** this was
the auto-opened sheet, `LogMealScreen` pops itself. The user asked to log one
food and changed their mind; leaving them on an empty meal screen they never
asked for would be an extra back-tap. Nothing needs deleting: `_autoSave`
never persists an empty meal. Sheets opened later from inside the screen
("Add another food") keep today's behaviour.

### 2.6 Mobile entry point: an icon button on the food card, not a gesture

`_FoodCard` in `foods_tab.dart` replaces its trailing chevron with an
`IconButton` (`Icons.add_circle_outline`, tooltip "Add to meal"); the card
body keeps tap-to-edit and swipe-left-to-delete.

- Rejected: swipe right. Undiscoverable, and the card already has a swipe.
- Rejected: long-press menu. Undiscoverable, and a two-step action for what
  should be the fastest path.
- Rejected: moving "edit" behind a button and making the card tap log. Changes
  an existing behaviour users rely on.

The chevron's "this opens something" hint is lost; the whole card still has
its ink ripple, which is how the recipe cards already work.

### 2.7 Web: the dialog gets a meal-type selector only when opened from Foods

`AddMealEntryDialog` requires a `mealType` today because it is always opened
from a meal-type section in `MealsView`. From Foods there is no section, so:

- New prop `initialFood?: FoodResponse`. When set, the dialog renders the same
  four meal-type chips as `LogRecipeDialog`, above the mode tabs, and keeps the
  selected type in state. The `mealType` prop becomes the initial value.
- Default type: `defaultMealType()` moved out of `LogRecipeDialog.tsx` into a
  shared `web/src/features/nutrition/mealTypeDefault.ts` and reused by both.
- Changing the type **after** the first item has created the meal re-runs
  `schedulePersist(items)`; the update payload uses the state value instead of
  `meal?.mealType ?? mealType`. So the type can be corrected at any time, as on
  mobile.
- The title stays `addTitle` ("Add to {meal}"), tracking the selected chip.
- Opened from `MealsView`, the dialog is unchanged (no chips) — the section the
  user clicked *is* the meal-type choice.
- Rejected: always defaulting to Snack / asking in a separate step first. The
  time-of-day default is right most of the time and one click fixes it.

### 2.8 Web: the date is the top-bar date, shown in the title when not today

The dialog uses `useDateStore().date`, as `LogRecipeDialog` does from the
Recipes tab. When that date is not today, the title reads
"Add to Lunch · Sep 21" so a user who browsed back to yesterday on the Meals
tab doesn't unknowingly log there.

- Rejected: always today. It would silently disagree with the Meals tab, which
  logs to the store date, and with the Recipes tab.

### 2.9 Web entry points: a row action and an editor button

- `FoodsView` columns get a trailing, unlabeled action column with an icon
  button (`add_circle`, `aria-label` "Add to meal"). Its `onClick` calls
  `e.stopPropagation()` so it doesn't also select the row via `onRowClick`.
- `FoodEditor` shows a secondary "Add to meal" button when editing an existing
  food (`food != null`), next to Save/Cancel. It doesn't appear while creating
  a food, because there is nothing to log yet (see Non-goals).
- The dialog is rendered by `FoodsView` (state `loggingFood`), as
  `RecipesView` renders `LogRecipeDialog`.
- When the dialog closes after at least one item was saved, `FoodsView` shows
  a success toast "Added to {meal}". The user stays on the Foods tab.

### 2.10 No backend change

Both clients already create meals from `{ foodId | foodClientId, grams }`. The
feature is purely navigation + a pre-filled popup. The foods API, meals API
and sync are untouched.

## 3. UI spec

### 3.1 Mobile — `foods_tab.dart`, `_FoodCard`

- Trailing: `SyncStatusIndicator` then
  `IconButton(icon: Icons.add_circle_outline, tooltip: l10n.addToMealTooltip, color: scheme.primary, visualDensity: VisualDensity.compact)`.
  The chevron is removed.
- `onAddToMeal` callback wired from both `build` (paginated list) and
  `_buildSearchResults` (search list) — the two call sites of `_FoodCard`.
- Handler:
  `Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => LogMealScreen(initialFood: food)))`
  — same navigator as `nutrition_screen.dart` `_logMeal`.

### 3.2 Mobile — `log_meal_screen.dart`

- `const LogMealScreen({super.key, this.meal, this.initialFood})`, with
  `assert(meal == null || initialFood == null)`.
- `_addEntry({Food? preselected, bool closeScreenOnCancel = false})`: passes
  `preselectedFood: preselected` to the sheet; on `null` result, if
  `closeScreenOnCancel && _entries.isEmpty && mounted`, calls
  `Navigator.of(context).pop()`.
- The meal type defaults from the clock and the date is "now", as for any new
  meal.

### 3.3 Mobile — `widgets/add_meal_entry_sheet.dart`

- New field `final Food? preselectedFood;` +
  `assert(initialFood == null || preselectedFood == null)`.
- `initState`: `_food = widget.initialFood ?? widget.preselectedFood`.
- `Autocomplete<Food>(initialValue: TextEditingValue(text: preselected.name), …)`.
- Food field `autofocus: widget.preselectedFood == null`; quantity field
  `autofocus: _isEditing || widget.preselectedFood != null`.
- `recents` empty when `preselectedFood != null`.
- One-time prefill in `build` (see §2.3).
- Clearing the food (✕) returns to normal add mode; picking another food runs
  the existing `onSelected` path unchanged.

### 3.4 Web — `FoodsView.tsx`

- Action column (`key: "actions"`, `header: ""`, `align: "right"`, not
  sortable) with the icon button.
- `const [loggingFood, setLoggingFood] = useState<FoodResponse | null>(null)`.
- Renders
  `<AddMealEntryDialog initialFood={loggingFood} mealType={defaultMealType()} date={date} onClose={…} />`,
  with `date` from `useDateStore()`.
- `FoodEditor` gets `onAddToMeal?: (food) => void`.

### 3.5 Web — `AddMealEntryDialog.tsx`

- Props: `initialFood?: FoodResponse`; `mealType` becomes an initial value held
  in state.
- Meal-type chip row (markup copied from `LogRecipeDialog`) shown only when
  `initialFood` is set.
- Title suffix ` · {MMM d}` when `date` is not today and `initialFood` is set.
- `<SearchMode initialPicked={initialFood} …>`: `useState(initialPicked ?? null)`
  and grams initialised from usage (see §5 Edge cases for usage still
  loading).
- Mode tab starts on "search"; "Change" returns to the normal search list.
- `onClose` reports whether anything was saved (`mealId != null`), so
  `FoodsView` can decide on the toast.

### 3.6 Strings

| Key | en | hu |
|---|---|---|
| mobile `addToMealTooltip` | Add to meal | Hozzáadás étkezéshez |
| web `nutrition.foodsView.addToMeal` | Add to meal | Hozzáadás étkezéshez |
| web `nutrition.foodsView.addedToMeal` | Added to {meal} | Hozzáadva: {meal} |

Mobile keys go through the `localization` skill (both ARB files).

## 4. Order of work

### 4.1 Milestones

| Milestone | Demo | Steps |
|---|---|---|
| **M1 — Mobile** | On a phone: Foods tab → ⊕ on a food → meal screen with the popup filled in, keyboard up on quantity → Add → meal saved | Prompts 1–3 |
| **M2 — Web** | In the browser: Foods table → ⊕ on a row → dialog with the food picked, quantity focused, meal type chips → Add → toast, meal visible on Meals tab | Prompts 4–7 |

M1 on its own is the smallest version worth using; M2 is independent of M1
and can land in either order.

## Prompt 1 — Mobile UI: pre-selected mode in `AddMealEntrySheet` ✅

Add `preselectedFood` to `add_meal_entry_sheet.dart` per §2.2, §2.3, §3.3.
Nothing calls it yet.

Verify: extend `mobile/test/features/nutrition/presentation/add_meal_entry_sheet_test.dart`:
the food field shows the name; the quantity field has focus; with a usage
entry, the quantity is the last-used grams; with usage arriving after the
first frame it still prefills; typing before usage arrives is not overwritten;
Add pops `(food: preselected, grams: …)`; ✕ clears the food and the recents
row appears again. `flutter test test/features/nutrition`.

## Prompt 2 — Mobile UI: `LogMealScreen(initialFood:)` auto-opens the sheet ✅

Per §2.4, §2.5, §3.2. Still no entry point.

Verify: new `log_meal_screen_initial_food_test.dart` with an overridden
`mealControllerProvider`: pumping `LogMealScreen(initialFood: f)` shows the
sheet after one frame; Add → one entry card, `logMeal` called once with that
food; dismissing the sheet pops the route; dismissing a *later* sheet
("Add another food") after an entry exists does not.

## Prompt 3 — Mobile UI: "Add to meal" button on the food card ✅

Per §2.6, §3.1, plus the `addToMealTooltip` string (localization skill).

Verify: widget test on `FoodsTab`: tapping the icon pushes `LogMealScreen`;
tapping the card body still opens `AddFoodSheet`; works from search results
too. Manual on a device: keyboard is numeric and up, and the budget preview is
visible above it.

## Prompt 4 — Web: extract `defaultMealType()`

Move it from `LogRecipeDialog.tsx` to
`web/src/features/nutrition/mealTypeDefault.ts`; `LogRecipeDialog` imports it.
Behaviour unchanged.

Verify: `mealTypeDefault.test.ts` covering each boundary hour; `npm test`,
`npm run lint`, `npx tsc --noEmit`.

## Prompt 5 — Web: `AddMealEntryDialog` accepts `initialFood`

Per §2.7, §2.8, §3.5: `initialPicked` in `SearchMode`, meal type in state, chip
row and date suffix when `initialFood` is set, `onClose(saved)`. No caller yet;
`MealsView` must render exactly as before.

Verify: type-check and lint. In the browser preview (temporary local harness
or Prompt 6 landing together in review) check that the Meals tab dialog has no
chips and still creates a meal per section.

## Prompt 6 — Web: row action in `FoodsView`

Per §2.9, §3.4: action column, `loggingFood` state, dialog, toast, strings in
`web/messages/en.json` + `hu.json`.

Verify in the browser preview: click ⊕ → the row is **not** selected / the
editor doesn't open; the dialog shows the food, the quantity is focused and
selected; Add → toast; Meals tab shows the meal under the chosen type on the
top-bar date; changing the chip after adding moves the meal.

## Prompt 7 — Web: "Add to meal" in `FoodEditor`

Per §2.9: button shown only for an existing food; opens the same dialog via
`onAddToMeal`.

Verify in the browser preview: button absent in "New food", present when a
row is selected, opens the dialog.

## 5. After implementation

- Set `Status:` here; add row `75` to the table in `docs/README.md` and bump
  "currently up to" there.
- Screenshots in the PR description for both platforms (light + dark).

## Non-goals (deferred)

- **"Add to meal" straight after creating a food / scanning a barcode.** The
  natural next step (snackbar action on mobile `AddFoodSheet` save, a button in
  the web editor after creating), but it touches the create flows and the
  offline "food not synced yet" path on web. Worth a follow-up once this lands.
- **Adding to an *existing* meal** ("add to today's lunch"). Needs a meal
  picker; always creates a new meal, as "Log meal" does today.
- **Multi-select foods → one meal.**
- **A "View" action in the web toast** switching to the Meals tab.
- **Aligning the time-of-day meal-type defaults.** Mobile
  (`_mealTypeForHour`: 15–17 and 22+ → snack) and web (`defaultMealType`: <11,
  <15, <21) disagree even though the web comment says "mirrors mobile". This
  plan only moves the web function; fixing the boundaries is its own change.
- **Admin / trainer views** (`admin/nutrition`, `ClientNutritionTab`) — no
  logging there.
- Backend changes of any kind.

## Edge cases

- **Mobile — food not synced yet** (created offline, still has a sync
  indicator). Logging it works, as in the normal flow: the entry references
  `foodClientId` and the outbox sends the food before the meal.
- **Mobile — food deleted on another device while the sheet is open.** Same as
  today's flow: the entry references a food that is gone; the meal sync fails
  with the existing 4xx handling. Not made worse.
- **Mobile — the food has no calories** (`caloriesPer100g == 0`). The impact
  preview is hidden (existing rule); Add still works.
- **Mobile — user taps ⊕ twice quickly.** Only one route is pushed: the
  Navigator absorbs pointers while a push is in flight, so no guard flag is
  needed (a flag was tried and the test passed with it removed).
  `foods_tab_add_to_meal_test.dart` keeps a double-tap test as a regression
  check.
- **Mobile — cancel after changing meal type / time but with no entries.**
  Screen still closes (§2.5); nothing was persisted, so nothing is lost that
  was ever saved.
- **Web — hidden foods.** The Foods table lists hidden (custom macro) foods;
  they can be logged via ⊕. "Change" goes back to the normal search, which
  excludes hidden foods, as today.
- **Web — usage not loaded when the dialog opens.** `mealApi.list` may still be
  loading, so `usage` is empty on first render. `SearchMode` fills the grams
  once usage arrives if the input is still empty and the user hasn't typed
  (same rule as mobile §2.3); otherwise the field just starts empty and
  focused.
- **Web — top-bar date in the future.** Logs there, as the Meals tab does
  today; the title suffix makes it visible.
- **Web — dialog closed while the first create is in flight.** Existing
  behaviour: the create completes, the meal exists. The toast decision uses
  `mealId`, which may still be null at that moment, so the toast can be
  skipped for that one case — acceptable, the meal still appears.

## Test plan

| Layer | What | Where |
|---|---|---|
| Mobile widget | Pre-selected sheet: focus, prefill (sync + late usage), no overwrite, clear, submit | `add_meal_entry_sheet_test.dart` |
| Mobile widget | `LogMealScreen(initialFood:)` auto-open, add, cancel-closes, later cancel doesn't | new `log_meal_screen_initial_food_test.dart` |
| Mobile widget | Foods card ⊕ vs card tap, search list, double tap | new `foods_tab_add_to_meal_test.dart` |
| Web unit | `defaultMealType` boundaries | `mealTypeDefault.test.ts` |
| Web manual (browser preview) | Row action, focus, chips, date suffix, toast, Meals tab result, Meals-tab dialog unchanged | Prompt 5–7 verification |
| Regression | Existing `add_meal_entry_sheet_test.dart` edit/add cases unchanged | — |

The web has no component-test setup (only `*.test.ts`); adding React Testing
Library for this feature isn't justified, so the dialog is verified in the
browser preview.

## Suggested PR split

1. **Mobile** — Prompts 1–3 (one PR, ~3 commits; each prompt passes tests on
   its own).
2. **Web** — Prompts 4–7 (one PR, or 4 alone first if review wants the
   refactor isolated).

## Risk checkpoints where a failure would be silent

- **Wrong grams from a late prefill.** If the one-time prefill (§2.3) doesn't
  respect `_gramsAutoFilled` / a typed value, a user who typed "250" quickly
  gets it silently replaced with last time's "100" and logs the wrong amount.
  This is the main thing to review in Prompt 1, and the test must cover it.
- **Pre-selected mode leaking edit semantics.** If `preselectedFood` is ever
  routed through `initialFood`, the budget preview subtracts a phantom "old"
  contribution and shows more calories left than is true. Review
  `_buildImpactPreview` for use of `widget.initialFood`.
- **Web meal type change not persisted.** If the update payload keeps reading
  the prop (`meal?.mealType ?? mealType`) instead of state, changing the chip
  after the first item looks right in the dialog but the saved meal keeps the
  old type. Check it on the Meals tab, not just in the dialog.
- **Web row click bubbling.** Without `stopPropagation` the editor panel opens
  behind the dialog; after closing it, a Save there would overwrite the food.
  Easy to miss because the dialog covers it.
- **Web wrong day.** Logging to the top-bar date instead of today is intended
  (§2.8), but if the title suffix is missing the user won't notice a meal
  landing on yesterday.
- **Mobile cancel-closes-screen firing on the wrong sheet.** If
  `closeScreenOnCancel` isn't limited to the auto-opened sheet, dismissing
  "Add another food" on a meal that already has entries would kick the user
  out of the screen. Entries are saved so no data is lost, but it's a
  confusing bug.
