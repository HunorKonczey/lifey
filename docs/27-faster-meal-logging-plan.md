# Faster Meal Logging Plan (Roadmap #5)

Goal: cut the number of taps/clicks needed to log a typical meal. Three
pillars, in line with the roadmap item:

1. Recent + frequent foods surfaced first in the add-entry flow
2. Polished copy: "copy yesterday's meal" and "copy a whole previous day"
   (a one-shot duplicate already exists on both platforms — this refines it)
3. Last-used quantity prefilled when re-picking a food

Guiding constraint: **no backend changes**. Everything below is derivable
from data both clients already have (meal history + foods). An explicit
"favorite" flag on foods is deliberately deferred (see Non-goals).

## Current state

Mobile (Flutter):

* `AddMealEntrySheet` — Autocomplete over the food catalog; with an empty
  query it lists foods in catalog order, grams always start empty.
* `MealsTab` → `_MealCard` has a copy icon; `MealController.duplicateMeal`
  re-creates the meal at `DateTime.now()` keeping meal type/name/entries.
  One tap, success snackbar, no way to tweak grams afterwards without
  hunting for the new card.
* Offline-first: meals/foods live in Drift, so usage stats can be computed
  locally with a watch query.

Web (Next.js):

* `MealsView` groups the selected day by meal type; each group has a dashed
  "+ Add to X" button. Duplicate exists behind a confirm dialog and always
  copies to `new Date()` — even when the user is viewing a past day
  (arguably a bug; fixed below).
* `AddMealEntryDialog` `SearchMode` — empty search shows the first 8
  catalog foods in arbitrary order; grams always start empty.
* All meals come from `mealApi.list` (already cached under
  `queryKeys.meals.all()`), so usage stats are computable client-side.

## Shared concept: food usage stats

For each non-hidden food, derive from meal history:

* `lastUsedAt` — dateTime of the most recent meal containing it
* `useCount` — number of meal entries referencing it (cap the window to the
  last 90 days so ancient habits don't dominate)
* `lastGrams` — quantity from the most recent entry

Ordering rule for the suggestion list when the search box is empty:

1. **Recents** — top 6 by `lastUsedAt`
2. **Frequents** — next: remaining foods with `useCount >= 2`, by `useCount`
   desc then `lastUsedAt` desc
3. Rest of the catalog alphabetically

While typing, keep the existing substring filter but sort matches with the
same usage ordering instead of catalog order — typing 2 letters should
already put the food you log daily at the top.

Hidden foods (one-off macro entries) are excluded everywhere, matching the
web's existing `!f.hidden` filter.

## Mobile plan

### M1 — Usage stats stream (data layer)

* `MealRepository.watchFoodUsage()` → `Stream<Map<String, FoodUsage>>`
  keyed by `foodClientId`; single Drift join over
  `mealEntries ⋈ meals ⋈ foods` (same atomic-join pattern as `watchAll`),
  aggregated in Dart. `FoodUsage` = `({DateTime lastUsedAt, int useCount,
  double lastGrams})`, new record/class in `domain/`.
* `foodUsageProvider` in `application/` (plain `StreamProvider` wrapping the
  repo stream).

### M2 — Add-entry sheet: recents + prefill

`AddMealEntrySheet` changes (design stays: same Material text fields,
bottom-sheet layout):

* **Recent chip row** above the food field (add mode only): horizontal
  scroll of up to 6 pills for the most recent foods — same pill language as
  `_MealTypeButton` (`surfaceContainerHigh`, radius 14, 12.5px w600 label).
  Label: food name; tapping a chip selects the food and prefills grams with
  `lastGrams`, focus jumps to the grams field. Row is hidden when there is
  no history yet.
* **Autocomplete ordering**: `optionsBuilder` sorts by the usage ordering
  above (empty query and typed query alike).
* **Grams prefill**: when a food is picked (chip or autocomplete) and the
  grams field is still empty, prefill `lastGrams` with the text selected,
  so typing immediately overwrites it. Never prefill in edit mode.

### M3 — Copy polish + copy a whole day

* **Snackbar with edit affordance**: after the existing one-tap duplicate,
  the success snackbar gets an "Edit" action that pushes `LogMealScreen`
  for the freshly created meal (the `Meal` can be constructed locally from
  the source meal + returned `clientId` + `DateTime.now()`). Requires
  `AppSnackbar` to support an optional action; add it if it doesn't.
* **`MealController.copyDay(DateTime sourceDay, DateTime targetDay)`**:
  loads the source day's meals from the repo and re-creates each one with
  the original time-of-day on `targetDay` (meal types and names preserved).
  Sequential `create` calls in a loop; each enqueues its own outbox entry,
  so offline works for free.
* **Entry point 1 — empty today**: when `MealsTab` shows the today filter
  and today is empty but yesterday has meals, the `EmptyView` gains an
  action button "Copy yesterday" (extend `EmptyView` with an optional
  action — additive, other usages unaffected).
* **Entry point 2 — always available**: a small copy-day icon button in the
  Meals tab header row (next to the date-range filter bar) opens a bottom
  sheet listing the previous 7 days that have meals — each row: weekday +
  date, meal count, total kcal (reusing the meals-tab card typography).
  Tapping a day runs `copyDay(thatDay, today)`. If today already has meals,
  the sheet row subtitle notes "adds N meals to today" — copying appends,
  never replaces.
* Success snackbar after a day copy: "N meals copied".

### M4 — l10n (mobile)

New keys in `app_en.arb` / `app_hu.arb`: recent-chips a11y label, "Copy
yesterday", copy-day sheet title, "adds N meals" subtitle, "N meals
copied", "Edit" snackbar action.

## Web plan

### W1 — Recents in `AddMealEntryDialog`

* Add the meals query (`queryKeys.meals.all()`) to the dialog (cache hit —
  `MealsView` already fetched it) and compute the same usage stats in a
  small pure helper `src/features/nutrition/usage.ts` (unit-testable).
* `SearchMode`, empty search: replace the arbitrary first-8 list with a
  **Recents** section — same row style as current matches, plus a muted
  right-aligned "last: 150 g" hint. A tiny uppercase section label
  ("Recent") in the existing `text-xs font-semibold on-surface-variant`
  style.
* Picking a food prefills the grams input with `lastGrams` (text selected /
  easily overwritten); typed-search results are sorted by usage too.

### W2 — Copy polish

* **Fix duplicate target date**: duplicate into the currently selected day
  (`logTimestampFor(date)` with the source meal's time-of-day), not
  `new Date()` — consistent with everything else on the page honouring the
  date store.
* **Drop the confirm dialog** for single-meal duplicate: copying is
  non-destructive and delete is one click; replace with the existing toast.
  (Keep confirm only for whole-day copy, which creates many rows.)

### W3 — Copy yesterday / whole day

* **Per-group ghost button**: in a meal group that is empty for the
  selected day, if the previous day has meals of that type, render a second
  dashed button under "+ Add to X": "Copy yesterday's X · 450 kcal". One
  click creates those meals on the selected day (times preserved). Styling:
  identical to the existing dashed add button, `--on-surface-variant`.
* **Whole-day copy**: a text button at the bottom of the daily summary
  panel — "Copy previous day" — enabled when the previous day has meals.
  Opens the existing `ConfirmDialog` ("Copy N meals (1,850 kcal) from
  Tue, Jul 8?"); confirm fires N `mealApi.create` calls via one mutation
  (`Promise.all`), then invalidates `queryKeys.meals.all()`.
* i18n: new keys in `messages/en.json` / `messages/hu.json`.

## Non-goals (deferred)

* **Explicit favorites (pin) flag on foods** — needs a Flyway migration,
  DTO changes, mobile Drift schema bump + sync payload, and UI on both
  platforms. Computed frequents likely cover 90% of the value; revisit only
  if users ask for pinning after this ships.
* Backend "recent foods" endpoint — unnecessary while both clients hold
  full meal history.
* Copying across users / trainer-driven copying.

## Edge cases

* **Copy day appends** — never deduplicates or replaces existing meals on
  the target day; the confirm/sheet copy makes that explicit.
* **Source entry's food deleted/missing** — skip that entry when copying;
  if a meal ends up with zero entries, skip the meal (mobile `create`
  requires entries to be meaningful; web same).
* **Hidden foods** — excluded from recents/frequents, but *copying* a meal
  that references a hidden food keeps working (entries reference the food
  id directly, unchanged from today).
* **Empty history** — chip row / recents section simply don't render; the
  sheet looks exactly like today.
* **Offline (mobile)** — usage stats and copies are pure local-DB
  operations; the outbox syncs later. No new sync surface.

## Test plan

* Mobile: unit test for the usage aggregation (repo-level, in-memory
  Drift); widget test for grams prefill + recent chips; controller test for
  `copyDay` (times preserved, appends).
* Web: vitest for `usage.ts` ordering/lastGrams; component test or e2e step
  for "copy yesterday's meal" appearing only when yesterday has that meal
  type.

## Suggested PR split

1. **Mobile — recents + prefill** (M1, M2, M4 partial): biggest everyday
   win, no UX decisions pending.
2. **Mobile — copy polish + copy day** (M3, M4 rest).
3. **Web — recents + copy polish + copy day** (W1–W3): independent of the
   mobile PRs.

Rough effort: each PR is a small, self-contained change touching one
feature folder — no schema, no API, no sync changes anywhere.
