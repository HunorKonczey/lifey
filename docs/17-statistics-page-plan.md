# Statistics page – plan and prompts

> Goal: a standalone **Statistics** tab that generalizes the Weight tab's chart
> pattern to several daily metrics (protein, calories, workout duration, water,
> weight, etc.). We follow the existing `TimeSeriesChart` + range-selector
> (`WeightRange`) pattern and aggregate locally from the already-migrated
> feature repositories (meals, sessions, weight, water) — the same way
> `DailyStats` / `dashboardControllerProvider` does today.

---

## 1. Brainstorm – which statistics?

`DailyStats` (`features/dashboard/domain/daily_stats.dart`) already computes,
per day: `calories, protein, carbs, fat, workoutCount, water, latestWeight`.
The data sources already exist — they just need to be aggregated into daily
time series.

### Metrics (all daily, with a selectable time range)

| Metric | Source | Aggregation / day | Unit |
|---|---|---|---|
| **Calorie intake** | `Meal.totalCalories` (meals repo) | daily sum | kcal |
| **Protein** | `Meal.totalProtein` | daily sum | g |
| **Carbs** | `Meal.totalCarbs` | daily sum | g |
| **Fat** | `Meal.totalFat` | daily sum | g |
| **Workout duration** | `WorkoutSession.finishedAt - startedAt` | daily sum (minutes) | min |
| **Workout count** | `WorkoutSession` count | daily count | count |
| **Active calories burned** | `WorkoutSession.activeCalories` (Apple Health) | daily sum | kcal |
| **Average heart rate during workout** | `WorkoutSession.averageHeartRate` | daily average | bpm |
| **Water intake** | water entries | daily sum | ml / l |
| **Body weight** | `WeightEntry.weight` | last reading of the day | kg |
| **Total volume lifted** | `ExerciseSet.reps * weight` | daily sum | kg |

### Derived / advanced metrics (later phase)

- **Calorie balance**: intake kcal − burned kcal (energy balance line around 0).
- **Macro split**: protein/carb/fat % as a stacked bar or donut for a given
  day/period.
- **Protein per kg bodyweight**: `protein / latestWeight` (g/kg) — useful for
  athletes.
- **Streak / consistency**: how many days had a workout / hit the calorie goal.
- **Period summary (KPI cards)**: average, min, max, trend (↑/↓ vs. the
  previous period of the same length) for the selected range.

### UX concept

- Top: a **metric picker** (chip/dropdown) for which time series to view.
- Below it, the familiar **range SegmentedButton** from the Weight tab
  (week / month / quarter / all).
- A **summary bar** (KPI cards): average / sum / trend for the selected range.
- `TimeSeriesChart` renders the selected metric's time series.
- **Tappable points**: tapping a chart point (especially peaks) shows the
  exact value for that day (value + date) as a tooltip/label. This extends
  the shared `TimeSeriesChart`, so the Weight tab benefits too.
- Empty and error states follow the Weight tab's `EmptyView` / `ErrorView`
  pattern.

---

## 2. Architecture fit (key constraints)

Per `mobile/CLAUDE.md`:

- **Four-layer feature**: `domain/ · data/ · application/ · presentation/` —
  even if thin.
- **Riverpod** controller providers; after `@riverpod` annotations, run
  `dart run build_runner build`.
- Statistics is **read-only** → no new repository needed; combine the
  existing feature controllers' watch streams (like
  `dashboardControllerProvider` does).
- `TimeSeriesChart` (`shared/widgets/charts/`) should be **reused** — it's
  already feature-agnostic.
- **Generalize** the `WeightRange` enum into a shared `StatsRange` instead of
  copying it.
- New l10n keys go in `app_en.arb` (+ the other language files).

---

## 3. Incremental prompts (copy-pasteable)

The phases build on each other; each is a separate, small, reviewable diff.

### Prompt 0 – Extract the shared range

```
Extract the WeightRange + cutoff() logic in
features/weight/application/weight_range.dart into a reusable,
feature-independent StatsRange under shared/ (e.g. lib/shared/widgets/charts/
or lib/shared/stats/). WeightRangeController can stay weight-specific, but its
cutoff()/day-count logic should reference the shared enum so the statistics
tab doesn't duplicate it. Don't break existing imports; run the existing
weight tests. Only move the range logic — behavior should not change.
```

### Prompt 1 – Stats domain + metric definitions

```
Create a new feature: lib/features/statistics/.
In the domain/ layer, add a StatMetric enum (calories, protein, carbs, fat,
workoutMinutes, workoutCount, activeCalories, water, weight) with:
- an l10n-based label,
- a unit-of-measure string,
- an aggregation type (sum / average / lastOfDay).
Add a DailyStatPoint value object (date, value) that maps onto TimeSeriesPoint.
No business logic yet — just types and metric metadata.
Follow the four-layer feature split (mobile/CLAUDE.md).
```

### Prompt 2 – Aggregating application layer

```
Under lib/features/statistics/application/, write a provider that — following
the dashboardControllerProvider pattern — combines the watch streams of the
existing feature controllers (mealControllerProvider, workout session
controller, water entry repo, weightControllerProvider) into a
List<TimeSeriesPoint> for a selected StatMetric + StatsRange, daily:
- calories/protein/carbs/fat: daily sum of Meal's totalX,
- workoutMinutes: daily sum of WorkoutSession (finishedAt-startedAt) in
  minutes (skip unfinished sessions),
- workoutCount: daily session count,
- activeCalories: daily sum of WorkoutSession.activeCalories,
- water: daily water intake,
- weight: last WeightEntry of the day (per weight_chart_data.dart's
  latestPerDay logic).
Keep the selected metric and range in small Notifier providers (like
weightRangeControllerProvider, but for StatMetric too). No new repository —
read-only. Run build_runner if using @riverpod.
```

### Prompt 3 – Period summaries (KPI)

```
Add a provider to the application layer that computes period summaries from
the selected metric's current time series: sum, average, min, max, and the
trend vs. the previous period of the same length (signed % or absolute
delta). This should compute purely from the already-fetched points, not
re-query the repos.
```

### Prompt 4 – Presentation: Statistics screen

```
Build lib/features/statistics/presentation/statistics_screen.dart following
weight_screen.dart's structure:
- AppBar with a title,
- a metric picker at the top (SegmentedButton or DropdownMenu over StatMetric),
- the StatsRange SegmentedButton below it (week/month/quarter/all), matching
  the weight tab,
- a row of KPI summary cards (reuse the dashboard's stat_card.dart widget if
  it fits),
- TimeSeriesChart with the selected metric's points, using a label builder for
  the metric's unit,
- EmptyView for no data, ErrorView for errors, CircularProgressIndicator while
  loading — exactly as weight_screen does.
All user-facing text should come from l10n keys.
```

### Prompt 5 – Navigation / tab integration

```
Add the Statistics screen to the app shell navigation (go_router + the bottom
nav, alongside the Weight/Nutrition/Workouts tabs). Watch out for the FAB
heroTag pitfall (see the weight_screen comment: because of the IndexedStack,
every FAB needs a unique heroTag) — the statistics page likely has no FAB
anyway. Add an icon and an l10n-based tab label.
```

### Prompt 6 – Localization

```
Add all the new strings (page title, metric names, units, KPI labels,
empty/error states) to app_en.arb, and sync the other language arb files.
Regenerate the localization.
```

### Prompt 7 – Tappable points on the chart

```
Extend the shared TimeSeriesChart (shared/widgets/charts/time_series_chart.dart)
so tapping a point shows that point's exact value + date. The widget is
currently a non-interactive CustomPaint — make it tappable:
- wrap the CustomPaint in a GestureDetector/onTapDown, match the tap position
  to the nearest point (a hit test consistent with the painter's xFor/yFor
  logic),
- draw a small tooltip bubble with the formatted value above the selected
  point (the caller supplies a valueLabelBuilder, similar to the existing
  dateLabelBuilder/deltaLabelBuilder), including the date,
- tapping elsewhere / the same point again closes or moves the tooltip,
- highlight the selected point (larger/different-colored circle).
Keep it feature-agnostic: work only from TimeSeriesPoint and the builders.
Both the Weight tab and the Statistics tab should inherit this automatically —
don't duplicate logic. Make sure shouldRepaint triggers a redraw on selection
change.
```

### Prompt 8 – Tests

```
Write unit tests for the aggregating provider: per-metric daily aggregation,
empty data, range-filter boundaries (cutoff), and "last weight of the day"
selection. Also test the KPI/trend calculation (empty and single-point edge
cases). At the widget level, a smoke test is enough to confirm the screen
renders the correct view for empty/data/error states. Write a widget test for
TimeSeriesChart's tappable points: tapping a point shows the tooltip with the
expected value (and it's not shown before the tap).
```

---

## 4. Future extensions

- **Bar chart variant** alongside `TimeSeriesChart` (for daily discrete
  values, e.g. workout count looks better as bars than as a line).
- **Multiple metrics on one chart** (e.g. intake vs. burned kcal overlay).
- **Goal lines**: a horizontal reference for daily protein/calorie goals
  (from `UserSettings`, if available).
- **Macro donut** showing the average macro split for the selected period.
- **Export / share** (PNG or CSV) for the selected period.

---

## 5. Affected / reference files

- Pattern: `mobile/lib/features/weight/presentation/weight_screen.dart`
- Range pattern: `mobile/lib/features/weight/application/weight_range.dart`
- Last-of-day aggregation pattern: `mobile/lib/features/weight/application/weight_chart_data.dart`
- Reused chart: `mobile/lib/shared/widgets/charts/time_series_chart.dart`
- Data-combining pattern: `mobile/lib/features/dashboard/application/dashboard_controller.dart`
- Daily aggregate model: `mobile/lib/features/dashboard/domain/daily_stats.dart`
- KPI card: `mobile/lib/features/dashboard/presentation/widgets/stat_card.dart`
- Data source models: `meal.dart`, `workout_session.dart`, `weight_entry.dart`, water entries
