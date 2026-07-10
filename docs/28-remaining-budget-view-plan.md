# Remaining Budget View Plan (Roadmap #6)

Goal: answer "what's left today?" — remaining calories and protein — at the
two moments it matters: glancing at the dashboard, and while logging a meal
(where the number changes decisions: "do I still fit a snack in?").

Guiding constraint: **no backend changes**. Daily goals already live in
`/settings` (`dailyCalorieGoal`, `dailyProteinGoal`, both nullable) and both
clients already hold today's meals, so remaining = goal − consumed is a pure
client-side derivation.

## Current state

Mobile (Flutter):

* Dashboard hero calorie `StatCard` already shows a small "N kcal left" /
  "N kcal over" badge (`kcalLeftBadge` / `kcalOverBadge` l10n keys exist),
  and the protein card a "N g more" badge — but the remaining number is a
  small pill, and there is no "/ goal" context on the values.
* `LogMealScreen` shows the meal's own total (`_MealTotalCard`), but nothing
  about how the meal fits into the day. `AddMealEntrySheet` shows no macro
  info at all while picking a quantity.
* Macros tab `_FeaturedDayCard` (today) shows totals with no goal context.
* Goals are nullable; the dashboard hides the badges when unset.

Web (Next.js):

* Dashboard `HeroMetricCard` is already close to the target: consumed
  "/ goal", progress bar, "remaining N kcal" line, "over" badge. But the
  page passes `settings?.dailyCalorieGoal ?? 2000` — a user with no goal
  sees progress against an invented 2000 kcal (same for the macro rings and
  the meals summary: protein `?? 150`, etc.).
* `MealsView` daily summary panel shows consumed/goal bars but no explicit
  "left" number, and uses the same hardcoded fallbacks.
* `AddMealEntryDialog` shows no budget context while adding an entry.

So: web dashboard ≈ done, mobile dashboard ≈ half done; the genuinely new
surface is the **meal logging flow** on both platforms, plus fixing the
web's fake-goal fallbacks.

## Shared concept: remaining budget

For a given day (here always "today", local midnight boundary):

* `consumedKcal`, `consumedProtein` — sum over that day's meals
* `remainingKcal = dailyCalorieGoal − consumedKcal` (null when no goal)
* `remainingProtein = dailyProteinGoal − consumedProtein` (null when no goal)

Display rules, applied identically everywhere:

* **No goal set** → the remaining UI for that metric simply doesn't render
  (no invented defaults — fixes the web fallbacks). Where the whole surface
  would otherwise be empty, show a one-line "Set your daily goals" hint
  linking to settings.
* **Under budget** → "N kcal left" in the positive/metric colour.
* **Over budget** → "N kcal over" in the negative colour — never clamp to 0;
  seeing the overshoot is the point.
* Calories and protein only, per the roadmap item. Carbs/fat keep their
  existing ratio rings/bars — no new remaining UI for them.

## Mobile plan

### M1 — `remainingBudgetProvider` (application layer)

* `domain/remaining_budget.dart`: `RemainingBudget` model + pure
  `RemainingBudget.compute(DailyMacros? today, UserSettings settings)`
  (unit-testable, holds the consumed/goal/remaining fields for kcal and
  protein and the `isOver` / `hasGoal` accessors).
* `application/remaining_budget_provider.dart`: plain `Provider` combining
  `dailyMacrosProvider` (today's bucket — complete for today regardless of
  pagination, per the note in `daily_macros_controller.dart`) and
  `settingsControllerProvider`. Live by construction: `LogMealScreen`
  autosaves every entry mutation to Drift, so the meal stream → daily
  macros → this provider updates as the user builds a meal.

### M2 — Dashboard prominence

Small, additive changes to the existing cards (design language unchanged):

* Hero calorie `StatCard`: add `subtitle: '/ 2,200 kcal'` when a goal is set
  (`StatCard.subtitle` already exists — the steps card uses it). Keep the
  existing left/over badge and ring.
* Protein `StatCard`: same "/ N g" subtitle; verify `subtitle` renders in
  `compact: true` mode and extend `StatCard` if it doesn't.
* No new card — the badge + subtitle + ratio ring together read as "what's
  left" without redesigning the dashboard.

### M3 — Budget context in `LogMealScreen`

* New `_DayBudgetBar` widget under `_MealTotalCard` (and visible even before
  the first entry, replacing nothing): one row per metric with a goal —
  "Today: 1,460 / 2,200 kcal · 740 left" plus a thin progress bar, protein
  line below in the same style. Colours: `mc.calories` / `mc.protein`,
  switching the "left" fragment to `mc.negative` + "over" wording when
  exceeded.
* Data comes straight from `remainingBudgetProvider` — because of autosave
  the day totals already include the in-progress meal, so no local delta
  math is needed.
* Only rendered when `_dateTime` is today (logging for a past day gets no
  budget bar) and at least one of the two goals is set.

### M4 — Impact preview in `AddMealEntrySheet`

* When a food is selected, show a live one-liner under the grams field:
  "+320 kcal · 28 g protein" recomputed as the grams text changes (pure
  arithmetic from `food.caloriesPer100g` / `proteinPer100g`).
* When the sheet was opened from a today-dated meal and a calorie goal is
  set, append the outcome: "→ 420 kcal left" (or "120 over" in negative
  colour). Needs a new optional `showBudget`/`mealDateTime` parameter passed
  from `LogMealScreen`; edit mode subtracts the entry's current contribution
  first so the preview reflects the change, not a double-count.
* Muted `labelMedium` styling — helper text, not a warning.

### M5 — Macros tab today card

* `_FeaturedDayCard` gains the same goal context when goals are set: the
  calorie headline becomes "1,460 / 2,200" and a "740 kcal left · 52 g
  protein left" line appears under the proportion bar. Prior-day compact
  cards stay as they are.

### M6 — l10n

* Reuse `kcalLeftBadge` / `kcalOverBadge` / `proteinMoreBadge` where the
  format fits; new keys in `app_en.arb` / `app_hu.arb` for: the day-budget
  row ("Today", "N left", "N over"), the impact preview fragments, and the
  "Set your daily goals" hint.

## Web plan

### W1 — Kill the fake-goal fallbacks

* `dashboard/page.tsx`: pass real (possibly undefined) goals; `HeroMetricCard`
  and `MacroRing` accept an optional goal and render the no-goal state
  (value only, no bar/remaining, one shared "Set your daily goals" link to
  `/settings` shown once on the page).
* `MealsView` summary panel: same — drop `?? 2000` / `?? 150`, hide the bar
  for a metric without a goal.

### W2 — Explicit "left" in the MealsView summary

* Add a prominent remaining line at the top of the daily summary panel:
  "740 kcal left" (bold, `--goal-positive`; "N kcal over" in
  `--goal-negative` when exceeded) and "52 g protein left" beneath —
  mirroring `HeroMetricCard`'s existing remaining line so the two surfaces
  use identical wording (`dashboard.remaining` / `dashboard.over` messages,
  moved/aliased into a shared namespace if needed).
* Extract the computation into `src/features/nutrition/budget.ts` (pure,
  vitest-able) so `MealsView` and `AddMealEntryDialog` share it.

### W3 — Impact preview in `AddMealEntryDialog`

* Meals (`queryKeys.meals.all()`) and settings are already cached; while a
  food is selected and grams are typed, show the same "+320 kcal → 420 kcal
  left" helper line under the quantity input, computed against the dialog's
  `date` (only when that date is today — the dialog is also used for past
  days via the date store).
* i18n keys in `messages/en.json` / `messages/hu.json`.

## Non-goals (deferred)

* **iOS home-screen widget / Live Activity remaining display** — the widget
  snapshot pipeline exists, but changing the widget layout is its own task;
  the snapshot already carries the calorie goal if we pick it up later.
* Carbs/fat remaining numbers — rings/bars stay ratio-only.
* Dynamic budgets (adjusting the goal by workout/steps burn) — a different
  feature with real product questions; remaining is strictly goal − food.
* Trainer web views — trainer-set goals are roadmap #17.
* Backend changes — none needed; goals and meals are already served.

## Edge cases

* **No goals set** — no remaining UI, single settings hint per surface; the
  app looks like today otherwise (important for brand-new users).
* **Over budget** — negative remaining renders as "N over" in the negative
  colour; progress bars cap at 100% width but keep the over colour (both
  platforms already do this on their bars).
* **Past/future-dated meals** — logging-flow budget UI only renders for
  today; the dashboard/summary always mean "today" (mobile) / selected day
  (web `MealsView`, which already follows the date store — its remaining
  line follows the selected day too, which is the existing semantics of
  that panel).
* **Midnight rollover** — day bucketing uses local midnight, same as
  `dailyMacrosProvider`; a sheet left open across midnight may show the old
  day until rebuilt — acceptable.
* **Offline (mobile)** — settings and meals are both local; the provider
  works offline. A never-synced fresh install just has no goals → hidden.
* **Hidden/macro-only foods** — they carry calories like any entry and are
  already inside meal totals; nothing special to do.

## Test plan

* Mobile: unit tests for `RemainingBudget.compute` (no goals / partial
  goals / under / over); widget test for `_DayBudgetBar` (renders only for
  today + goal set, over-budget colour); widget test extension for
  `AddMealEntrySheet` impact preview (updates with grams, edit mode doesn't
  double-count).
* Web: vitest for `budget.ts`; component check that no-goal renders no bar
  and no invented 2000/150 numbers.

## Suggested PR split

1. **Mobile — provider + logging flow** (M1, M3, M4, M6 partial): the new
   value; self-contained in the nutrition feature folder.
2. **Mobile — dashboard + macros tab polish** (M2, M5, M6 rest): small,
   additive.
3. **Web — fallback fix + remaining + preview** (W1–W3): independent of the
   mobile PRs; W1 is arguably a bug fix and could ship alone if needed.

Rough effort: no schema, no API, no sync changes anywhere; the largest
single piece is the `LogMealScreen` budget bar.
