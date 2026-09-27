# Mobile Application Requirements

## Screens

### Dashboard

Display:

* Today's calories
* Today's macros
* Latest weight
* Recent workouts

### Nutrition

Features:

* Food list
* Recipe list
* Meal logging

### Recipes

Features:

* Create recipe
* Edit recipe
* Delete recipe

### Workout Templates

Features:

* Create template
* Edit template

### Workout Tracking

Features:

* Start workout
* Add exercise
* Add set
* Finish workout

### Weight Tracking

Features:

* Add weight
* View history

## Navigation

The client shell has a floating bottom bar (only the active tab shows its label):

* Today (dashboard)
* Nutrition
* Workouts
* Weight
* Statistics

A user with `ROLE_TRAINER` also has a **trainer view** (avatar menu → "Trainer view", marked with
the clay TRAINER label): a second shell with Clients, Calendar, Assigned and Programs — a bottom bar
on a phone, a 96 dp rail beside a list and a detail pane from 900 dp up.

## Offline Support

User should be able to:

* View data
* Add data
* Edit data

without internet connection.

## Free / Pro

Full design: [docs/landing_page/67-mobile-free-pro-plan.md](landing_page/67-mobile-free-pro-plan.md).
The app is free and fully usable; three things differ (`63` D-M5):

| | Free | Pro |
|---|---|---|
| Everything above — nutrition, workouts, cardio, weight, water, steps, watch, widgets, integrations | full | full |
| Statistics & history depth | last **30 days** | unlimited |
| AI calorie estimation | **3 / month** | unlimited (100/month fair use) |
| Ads | banner on the four tab roots + a rate-limited interstitial | none |

Four rules that constrain how any new screen is built:

1. **The server decides, the client reads fields.** `GET /api/v1/me/entitlements` returns
   `historyDays`, `aiCreditsRemaining`, `adsEnabled` — a gate reads the *field it needs*, never
   `tier`/`source` (D-P5), so changing a limit is a config change on the server, not a release.
2. **Every gate lives in `core/entitlements/`** and is enumerated in
   `test/core/entitlements/gated_surfaces_test.dart`. Adding a screen that should be gated and
   is not shows up as a failing list rather than as free Pro forever (D-P7).
3. **The history window is a presentation filter only** (D-P6). Sync keeps pulling and storing
   everything; a list stops at the cutoff and says so with a row that offers Pro. Implementing
   it in a repository query would look identical in a demo and destroy data on the next
   re-install.
4. **A client whose trainer pays gets Pro for free**, for as long as the relationship lasts plus
   a 7-day grace — and is never sold to while sponsored (D-P9).

Ads are limited to the four tab roots (dashboard, nutrition, workouts, statistics) and appear
nowhere else: not on detail screens, in chat, during an active session, on the watch or in
widgets. The one ad-adjacent CTA is the remove-ads button in the slot's own chrome row.

## UI and theme

The look of the app is the v2 design system, built by the redesign in
[`redesign/77-mobile-redesign-plan.md`](redesign/77-mobile-redesign-plan.md) (R0 defines it, R1–R6
apply it screen by screen, R7 closed it):

* **Tokens** — `mobile/lib/core/theme/`: palette (`context.palette`, `context.metricColors`), the
  type scale (`TextTheme` roles plus `AppType.number` for hero numbers), the four radii
  (`AppRadius.tag / control / card / hero` and `pill`), spacing, elevation and motion
  (`AppMotion`, which also honours "Remove animations").
* **Components** — `mobile/lib/shared/widgets/ds/`: `LifeyCard`, `ListGroup` / `ListRow`,
  `TintedChip`, `MetricTile`, `LifeyHeader` / `LifeySubpageHeader`, `showLifeySheet`,
  `LifeySegmented`, `NoticeCard`, …, all shown on the debug **Design gallery** (Settings → Debug).
* **Rules** — one hero number per screen; colour means data (metric colours only on their metric,
  brand olive only on controls); related data grouped in one card; Hungarian and 130 % text scale
  are the yardstick, so no label truncates.
* **Guard rails** — `dart run tool/design_audit.dart` (run from `mobile/`) counts hand-rolled
  `fontSize` / `Color(0x…)` / `BorderRadius.circular(n)` / `AppBar` literals outside the theme and
  the design system; it must read zero (`--strict` exits 1 otherwise). `test/core/theme/contrast_test.dart`
  keeps the palette WCAG AA, including every metric colour on its own chip tint.

Priorities behind it: fast interaction, few taps, mobile first.
