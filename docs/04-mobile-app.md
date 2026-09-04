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

Bottom navigation:

* Dashboard
* Nutrition
* Workouts
* Weight

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

## UI Priorities

* Fast interaction
* Minimal clicks
* Mobile-first experience

Design can remain simple during MVP.
