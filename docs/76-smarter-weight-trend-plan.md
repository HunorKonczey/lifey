# 76 – Smarter Weight Trend

Status: **built (2026-09-23)** — mobile only, as planned; see §7 for what the numbers actually
do and the one thing still unverified
Scope: mobile only — no backend, no schema, no sync change
Depends on: `docs/21-onboarding-user-details-plan.md` (`targetWeightKg`, already collected),
`docs/17-statistics-page-plan.md` (the shared `TimeSeriesChart`)

Roadmap item #11 (`05-improvement-roadmap.md`), both halves:

1. a **7-day moving average** instead of reading the raw daily points, and
2. the **goal weight and the date the trend would reach it**.

## 1. Why the raw line is the problem

Daily weight swings 0.5–1.5 kg on water alone. On the Weight tab that noise *is* the line: a
user who lost 300 g in a fortnight sees a zigzag and cannot tell direction from it. The data to
fix this is already on the device — this is a presentation feature, and deliberately stays one.

## 2. Decisions

**D-W1. The average is over a 7-day *window*, not the last 7 samples.** People skip days. Seven
samples can span three weeks, and averaging those would report a "weekly" number that isn't one.
Each day's trend value is the mean of every entry dated within the trailing 7 days.

**D-W2. A trend point needs at least two entries in its window.** With one, the "average" is the
raw value wearing a disguise — worse than drawing nothing, because it looks smoothed.

**D-W3. The raw line stays, dimmed.** "Instead of raw daily points" as the roadmap puts it costs
the user the thing they just typed in: their own weigh-in should stay visible. The raw series
drops to a thin, translucent line and keeps the tap targets; the trend is drawn solid on top.

**D-W4. The projection reads the trend, not the raw values.** Projecting from a noisy last point
would swing the estimated date by weeks depending on which morning the user last weighed in.

**D-W5. The rate is a least-squares slope over the last 28 days of trend**, not "first minus
last". Two endpoints make the estimate hostage to two days; four weeks is long enough to be
stable and short enough to follow a real change in direction.

**D-W6. The projection refuses to guess more often than it guesses.** It needs a goal, at least
4 trend days spanning 14 days, and a slope that actually moves toward the goal. Anything else
gets a plain sentence instead of a date — see §4. A number invented from three weigh-ins would be
believed, and it should not be.

**D-W7. The goal card lives on the Weight tab, not the Statistics tab.** The roadmap says
"statistics screen"; the Weight tab is where the weight statistics actually are, and where the
number the card is about was last typed. The Statistics tab's weight metric gets the trend line
(§3) but not the card — it is a metric browser, not a goal screen.

**D-W8. No new persistence, and nothing offline-breaking.** `targetWeightKg` comes from
`/user-details`, which is online-only (`21`). Offline, the card hides and the trend line keeps
working: the trend is computed from the local DB like every other chart.

## 3. What is built

| Piece | File |
|---|---|
| `movingAverage` (D-W1/D-W2), `WeightProjection` + `projectGoal` (D-W4–D-W6) | `mobile/lib/features/weight/domain/weight_trend.dart` |
| `weightTrendProvider`, `weightGoalProjectionProvider` | `mobile/lib/features/weight/application/weight_trend_data.dart` |
| `trendValues` on the shared chart — a second line over the same geometry | `mobile/lib/shared/widgets/charts/time_series_chart.dart` |
| Goal card + the chart's trend caption | `mobile/lib/features/weight/presentation/` |
| Trend line on the Statistics tab's weight metric | `mobile/lib/features/statistics/` |

`trendValues` is a `List<double?>` parallel to `points`, so the chart keeps one x-scale, one set
of tap targets and one tooltip. Nulls are gaps, drawn as gaps.

## 4. What the card says

| State | Condition | Copy |
|---|---|---|
| On track | slope moves toward the goal | goal, remaining kg, "−0.4 kg/week", "around 12 March" |
| Reached | within 0.2 kg of the goal | "You're at your goal weight" |
| Wrong way | slope moves away from the goal | remaining kg, rate, "the trend is moving away from your goal" |
| Too slow | ETA beyond 2 years | rate, "at this rate it would take years" |
| Not enough data | fewer than 4 trend days, or under 14 days of span | "keep weighing in for a couple of weeks" |
| No goal | `targetWeightKg` is null | the card is hidden; setting one is in onboarding/Settings |

## 5. Tests

Unit: the window rule against a gappy series (D-W1), the two-entry rule (D-W2), slope and ETA
arithmetic, and each state in §4 including the wrong-way and too-slow guards. Widget: the card's
states on the Weight tab, and that the chart renders a trend line without disturbing the tooltip.

## 6. Out of scope

Goal-weight editing from the Weight tab (it lives in onboarding details), notifications about the
projection, and any backend aggregate — everything here is derived on the device from data that
is already local.

---

## 7. As built (2026-09-23)

Everything in §3 landed as written, with the decisions intact. Three notes worth keeping:

- **The trend lags, and the card says what the trend says.** A 7-day mean sits about three days
  behind a steadily falling raw line, so "kg to go" reads slightly higher than the last weigh-in
  suggests — that is the point of D-W4, not a rounding bug. The tests pin the arithmetic
  (`weight_trend_test.dart`: 87.4 trend against an 87.1 raw last point).
- **A flat trend is "wrong way", not "too slow".** Zero slope never reaches the goal, so it takes
  the same copy as moving away rather than a date centuries out.
- **The rate comes out a touch flatter than the underlying loss** (−0.68 kg/week against a raw
  −0.7), because the first trend values average partial windows. Real enough to act on, and
  honest: it is the smoothed series' own slope, which is what the card claims to show.

Not verified: none of this has been seen on a device. The chart's trend line, the dimmed raw
line (D-W3) and the card's layout are covered by widget tests, not eyes.
