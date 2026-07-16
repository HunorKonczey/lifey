# Streaks and Weekly Recap Plan (Roadmap #7)

Goal: make daily consistency visible and rewarding — flame-style streaks for
the three daily goals (calories, steps, water), and a "your week in review"
recap screen (workouts done, average calories, weight trend).

Guiding constraint: **no backend changes, no sync changes, no persisted streak
state**. Every input already lives in the local Drift DB (meals, water
entries, daily step counts, workout sessions, weight entries) and the daily
goals already live in synced `UserSettings` (`dailyCalorieGoal`,
`dailyWaterGoalLiters`, `dailyStepGoal`). Streaks and the recap are **pure
derivations recomputed from local data on every read** — never stored. That
makes them self-healing: late-arriving data (a HealthKit step import for a
past day, a sync from another device, an edited meal) silently corrects the
streak, which a persisted counter could never do.

## Current state

* All five data sources are local-first with watch streams:
  `MealRepository`, `WaterEntryRepository.watchAll`,
  `StepCountRepository.watchAll`, `workoutSessionControllerProvider`,
  `weightControllerProvider`. A fresh install gets full history via the
  initial full pull (`pull_engine.dart`), so history-based computation is
  accurate after first sync.
* **Pagination caveat**: `mealControllerProvider` is a 40-meal UI window, and
  `dailyMacrosProvider` aggregates from it — its own doc comment carries a
  TODO to replace this with a Drift-level daily aggregation
  (`daily_macros_controller.dart:17`). A calorie streak over months **cannot**
  read the paged window; this plan implements that TODO.
* Goals are nullable in `UserSettings`; the dashboard already hides
  goal-dependent UI when unset (same rule here).
* The dashboard is a derived plain `Provider`
  (`dashboardControllerProvider`) recomputing synchronously from watched
  streams — the streak provider follows the same pattern.
* Local calendar-day bucketing (`_localDay` in `stat_chart_data.dart`,
  `_isToday` in the dashboard/water code) is the established day-boundary
  convention — streaks reuse it.
* `NotificationService` exists for local notifications (used by the step-goal
  notifier); a recap-ready notification is possible but deferred (see
  Non-goals).
* Device-local (non-synced) prefs use `FlutterSecureStorage` per the
  precedent in `core/health/health_preferences.dart` — the recap card
  dismissal state follows it.

## Shared concepts

### When is a day's goal "met"?

Per metric, for a local calendar day:

| Metric   | Goal source                    | Met when                                              |
|----------|--------------------------------|-------------------------------------------------------|
| Calories | `dailyCalorieGoal` (kcal, max) | ≥ 1 meal logged that day **and** day total ≤ goal     |
| Steps    | `dailyStepGoal` (min)          | day's step count ≥ goal                                |
| Water    | `dailyWaterGoalLiters` (min)   | sum of that day's entries ≥ goal                       |

Notes:

* Calories is a **budget** (stay under), steps/water are **floors** (reach
  it). An empty day must not count as a calorie success — hence the
  "≥ 1 meal logged" clause; otherwise never opening the app would build a
  streak.
* Goal unset → that metric has no streak and its UI doesn't render
  (consistent with the remaining-budget rules in
  `28-remaining-budget-view-plan.md`).
* No grace days / freezes in v1 — a miss resets to 0. Simple and honest;
  freezes are a gamification rabbit hole we can revisit.

### Streak counting rule

`currentStreak` = number of consecutive met days ending at **yesterday**,
**plus one if today is already met**. Today being not-yet-met never breaks
the streak (the day isn't over); today being met extends it immediately —
the satisfying moment is logging the glass of water that ticks the flame up.

`bestStreak` = longest run anywhere in history (cheap to compute in the same
single pass over the day list; shown in the recap, not on the dashboard).

### Day boundaries and time

* Bucket by device-local calendar day (`DateTime(local.year, month, day)`),
  identical to `stat_chart_data.dart` and the dashboard.
* Recompute on every provider emission — no baked-in "today" (the
  `watchTodayTotalLiters` doc comment explains the midnight-staleness trap;
  streak providers avoid it the same way by filtering per emission, plus the
  dashboard rebuild on app resume covers the common case).

## Mobile plan

New feature folder `lib/features/streaks/` (feature-based packaging; the
recap screen lives here too since streaks are its centerpiece and both share
the same aggregation layer).

### M1 — Drift-level daily aggregates (data layer)

* `MealRepository.watchDailyMacros()`: SQL `GROUP BY` day over
  meals × meal_entries returning `List<DailyMacros>` (all history — one row
  per day is tiny even after years). Rewire `dailyMacrosProvider` to it,
  resolving the accuracy TODO in `daily_macros_controller.dart` — the Macros
  tab "All" view becomes exact as a side effect.
  * Must respect the pending-delete filter like the other watch streams
    (`pendingDeleteFilter`), and bucket by **local** day — if bucketing in
    SQL over UTC timestamps is awkward, aggregate in Dart over a slim
    projection (day-precision truncation of `mealDateTime` + the four
    totals) instead; correctness over cleverness.
* Water: `WaterEntryRepository.watchDailyTotalsLiters()` — same shape
  (`Map<DateTime, double>` or a small record list). `watchAll` already loads
  every entry for statistics, so this is an aggregation of an existing
  stream, not a new query, unless row counts warrant SQL.
* Steps: `allStepCountsProvider` is already one row per day — no new query.

### M2 — Streak engine (domain + application)

* `domain/streak.dart`:
  * `enum StreakMetric { calories, steps, water }`
  * `class Streak { final StreakMetric metric; final int current; final int
    best; final bool todayMet; final bool active; }` (`active` = current > 0)
  * Pure static `Streak.compute({required Set<DateTime> metDays, required
    bool todayMet, required DateTime today})` — takes the set of met local
    days, walks backwards from yesterday, single pass for best. Fully
    unit-testable with synthetic dates, no clock/DB dependency.
* `application/streaks_provider.dart`: plain derived `Provider<List<Streak>>`
  combining `dailyMacrosProvider` (M1 version), the water daily totals,
  `allStepCountsProvider`, and `settingsControllerProvider`. Emits only
  metrics whose goal is set. Same synchronous-derivation pattern as
  `dashboardControllerProvider`.

### M3 — Dashboard streak chips

* New `presentation/widgets/streak_chip_row.dart`: a horizontal row of up to
  three compact chips under the day greeting on `DashboardScreen` — flame
  icon + count + metric icon (e.g. 🔥 12 · 💧). Rendering rules:
  * Metric with no goal → chip absent.
  * `current == 0` → muted/grey flame ("start a streak" affordance), not
    hidden — visibility is the motivation loop.
  * `todayMet` → filled/colored flame; not yet met today → outlined flame
    with the current count (communicates "still alive, act today").
* Row hidden entirely when no goals are set (brand-new users see today's
  dashboard unchanged).
* Tapping the row navigates to the weekly recap screen (M4) — one entry
  point serves both features.
* When a chip's count increases while the dashboard is visible (e.g. water
  logged from the dashboard card), a small implicit scale/fade animation on
  the changed chip is enough celebration for v1 — no confetti dependency.

### M4 — Weekly recap (domain + application)

* Week definition: **Monday–Sunday, device-local** (matches the ISO/EU
  expectation of the app's en/hu audience; hardcoded, not locale-driven, so
  the recap and streak logic can never disagree about the week edges).
* `domain/weekly_recap.dart` — value object for one week:
  * `workoutsDone` (count), `workoutMinutes` (finished sessions only, same
    rules as `StatMetric.workoutMinutes`: exclude `isUpcoming`, skip
    unfinished for minutes)
  * `avgCalories` (mean over **days with ≥ 1 meal**, not ÷7 — an unlogged
    day is missing data, not a 0-kcal day) + `loggedDayCount` so the UI can
    say "avg of 5 logged days"
  * `weightStart`, `weightEnd`, `weightDelta` — latest entry on/before the
    week's start vs latest entry in the week (reusing the latest-per-day
    convention from `_weightPoints`); null-safe when either side is missing
  * per-metric goal-hit counts (`caloriesDaysMet`, `stepsDaysMet`,
    `waterDaysMet` out of the days with a goal)
  * streak snapshot (current + best per metric, from M2)
* Pure `WeeklyRecap.compute(...)` over plain lists + a
  `weeklyRecapProvider(DateTime weekStart)` family combining the same
  sources as M2 plus sessions and weights. Default: the **last completed
  week**; the screen can page to earlier weeks.

### M5 — Weekly recap screen (presentation)

* `presentation/weekly_recap_screen.dart`, `GoRoute` `/recap` (top-level
  push, like `/settings`, not a shell tab).
* Layout (existing design language — `StatCard`, `_SectionTitle`-style
  labels, `time_series_chart` where a spark helps):
  1. Header: week range ("Jun 30 – Jul 6") with ◀ ▶ chevrons to page weeks
     (▶ disabled at the last completed week).
  2. Workouts: count + total minutes; small per-day dot strip (7 dots,
     filled where a session happened).
  3. Nutrition: average calories over logged days + "N/7 days within goal"
     when a calorie goal is set; a 7-point mini bar chart of daily kcal.
  4. Weight: start → end with delta and direction arrow (colors follow the
     existing `_WeightDeltaBadge` semantics); hidden when no entries.
  5. Goals & streaks: per metric "N/7 days met" + current/best streak.
  * Sections with no data collapse to a one-line empty hint (pattern:
    `_EmptyHint` on the dashboard).
* Entry points: streak chip row tap (M3) + the recap card (M6) + an app-bar
  action on the statistics screen (recap is statistics-adjacent).

### M6 — "Recap ready" dashboard card

* At the start of each week (Mon–Wed window), the dashboard shows a slim
  dismissible card above the meals section: "Your weekly recap is ready" →
  opens `/recap`.
* Shown only when the last completed week has *any* data (never for a
  brand-new user's empty week).
* Dismissal is device-local, not synced: `RecapPreferences` in the streaks
  feature storing `lastSeenRecapWeekStart` via `FlutterSecureStorage` (same
  precedent and justification as `health_preferences.dart` — a per-device
  "already saw it" flag is meaningless on another device). Opening the recap
  from any entry point also marks it seen.

### M7 — l10n

* New keys in `app_en.arb` / `app_hu.arb`: chip semantics/tooltips
  ("12-day calorie streak"), recap screen title + section titles, "avg of
  {n} logged days", "{n}/7 days met", week-range formatting, recap-ready
  card text, empty hints. Plural forms via ICU where counts appear
  (hu plural rules differ from en).

## Non-goals (deferred)

* **Push / local notification "your recap is ready"** — the plumbing exists
  (`NotificationService`, push infra from #8), but notification fatigue is a
  real risk; ship the passive card first, add an opt-in notification later
  if retention data justifies it.
* **Streak freezes / repair / grace days** — v1 is strict; revisit with
  real usage.
* **Protein or workout streaks** — roadmap names calories/steps/water;
  the engine is metric-generic so adding one later is a small diff.
* **Backend/web-admin surface** — trainer-side weekly summaries are already
  covered by the weekly trainer report email (#16); the user-facing web app
  can get recap parity later reusing the same computation rules, but the
  roadmap item is mobile.
* **Home-screen widget streak display** — the snapshot pipeline
  (`widget_snapshot_writer.dart`) could carry the streak later; separate
  task.
* **Sharing / social export of the recap** — out of scope.

## Edge cases

* **No goals set** — no chips, no goal sections in the recap; recap still
  works (workouts, avg calories, weight need no goals).
* **Late-arriving data** — HealthKit step imports for past days, another
  device's sync, retro-logged meals: streaks are derived, so they simply
  recompute; a broken streak can retroactively "un-break". This is the
  decisive argument for derivation over persisted counters.
* **Goal changed mid-history** — evaluated against the *current* goal for
  all days (only today's goal is stored; historic goal values don't exist).
  Accepted simplification — changing a goal may rewrite streak history, and
  that's fine.
* **Retro-editing a meal that breaks a past day** — same as above: the
  streak shrinks. Honest by design.
* **Timezone travel / DST** — local-day bucketing follows the device zone,
  same as everywhere else in the app; a flight can duplicate or shorten a
  day, we accept the app-wide convention.
* **Midnight rollover with the app open** — providers filter per emission
  (no baked-in today); a screen sitting idle across midnight refreshes on
  next emission/resume, matching existing dashboard behavior.
* **Fresh install pre-first-sync** — empty DB → zero streaks for a few
  seconds until the initial full pull lands; acceptable (whole app behaves
  this way offline-first).
* **Weeks with zero data** — recap paging skips nothing (empty weeks render
  with empty hints), but the recap-ready card suppresses itself (M6).
* **Unfinished / upcoming sessions** — excluded exactly as
  `stat_chart_data.dart` and the dashboard already exclude them
  (`isUpcoming`, null `finishedAt` for minutes).

## Test plan

* **Unit — streak engine**: `Streak.compute` with synthetic day sets: empty
  history; single met day today / yesterday; today unmet doesn't break;
  today met extends; gap resets; best-streak vs current; month-boundary and
  DST-transition days.
* **Unit — met-day derivation**: calories requires a logged meal (empty day
  ≠ met even with goal 2000); over-budget day not met; water/steps exact
  boundary (== goal counts).
* **Unit — recap**: `WeeklyRecap.compute` — avg over logged days only;
  weight delta with entries missing on either side; workout minutes skip
  unfinished; week paging boundaries (Mon–Sun inclusive).
* **Repository test**: `watchDailyMacros` equals the old in-memory
  aggregation on a seeded DB (guards the M1 rewire, incl. pending-delete
  filtering).
* **Widget**: chip row renders only goal-set metrics; unmet-today vs
  met-today visual states; recap screen golden-path with full and empty
  data; recap-ready card appears/dismisses and marks seen.

## Suggested PR split

1. **Daily aggregates + streak engine + dashboard chips** (M1–M3, M7
   partial): the daily-visible value, plus the `dailyMacrosProvider`
   accuracy fix.
2. **Weekly recap screen + recap-ready card** (M4–M6, M7 rest): builds on
   PR 1's providers; independent review surface.

Rough effort: no schema, no API, no sync changes; the largest pieces are the
recap screen UI and the M1 aggregation rewire (which pays down an existing
TODO).
