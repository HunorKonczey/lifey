# Android Widget + Workout Ongoing Notification — Implementation Plan

Android counterpart of roadmap item #9 (see
[24-ios-widget-live-activity-plan.md](24-ios-widget-live-activity-plan.md)):

* **Home screen widget** — today's calories (vs. goal); steps once Health
  Connect lands (see "Steps on Android" below)
* **Ongoing workout notification** — Android's stand-in for the iOS Live
  Activity: a persistent, silent notification during an active session with
  current exercise, set progress and a natively ticking rest chronometer

Android only; no backend changes. Everything here can be built and tested
in the current dev environment (Android builds run on Windows — unlike the
iOS plan's Mac-only native chunk).

## Relationship to the iOS Plan

Doc 24 deliberately made two choices that Android now cashes in on:

1. **The snapshot pipeline is shared.** `widget_snapshot_writer.dart` /
   `widget_snapshot_controller.dart` write via the `home_widget` package,
   which has an Android side (SharedPreferences + widget reload broadcast).
   The only change is dropping the iOS-only guard so the snapshot is
   written on Android too. Payload, debounce, lifecycle triggers, the
   pre-localized-labels decision: all identical.
2. **The Live Activity call sites are platform-neutral.** `LogSessionScreen`
   talks to `WorkoutLiveActivityService` at exactly the hooks listed in doc
   24 (start on first persist / scheduled start / resume, update on
   autosave, end on finish/discard). This plan gives that service an
   Android branch; the screen wiring is untouched. Rename the service to
   the platform-neutral **`WorkoutSessionNotifierService`** while at it
   (iOS branch → ActivityKit channel, Android branch → local notification,
   other platforms → no-op).

Whichever plan is implemented first builds the shared Dart pieces; the
second one only adds its platform branch.

## Key Design Decisions

### 1. Classic `AppWidgetProvider` + RemoteViews, not Glance

Jetpack Glance would pull the Compose runtime into a project that has no
Compose anywhere — a new framework for a two-cell static widget, against
the project's "no new frameworks without justification" rule. A Kotlin
`AppWidgetProvider` with XML `RemoteViews` layouts (~100 lines total) is
entirely sufficient: the widget renders a snapshot, it has no interaction
beyond "tap opens app".

### 2. Ongoing notification instead of a foreground service

Android has no ActivityKit; the idiomatic equivalents are an ongoing
notification or a foreground service. A foreground service is not needed,
for the same reason the iOS plan needs no push channel: **content only
changes while the app is foregrounded** (logging a set), and the ticking
timer is rendered by the OS itself (`usesChronometer`), not by our process.
The notification simply persists after backgrounding, chronometer running.
This avoids the whole FGS type-declaration / Play-policy surface
(`FOREGROUND_SERVICE_HEALTH` etc.).

Consequences accepted:

* Android 14+ lets users swipe away ongoing notifications → recreate it on
  the next `update()` call; if the user dismissed it they get it back only
  when they next interact with the session, which is fine.
* Process death leaves an orphan notification with a still-ticking
  chronometer → mirrored from the iOS orphan handling: on app start, if no
  in-progress session exists, cancel it (`endAll()` equivalent). After a
  reboot notifications are gone anyway; `WorkoutResumePrompt` recreates it
  when it reopens the active session.

### 3. One chronometer — anchored to the rest timer

A notification has a single `when`-based chronometer. Mid-workout the rest
count-up is the number that matters (this mirrors the in-app rest banner),
so:

* before the first logged set: `when = startedAt` → shows elapsed time
* after each logged set: `when = lastSetAt` → shows rest count-up
* elapsed total moves to `subText` as static "started HH:mm" text

`usesChronometer` ticks natively, so no per-second updates from Dart —
exactly parallel to `Text(timerInterval:)` on iOS.

### 4. `flutter_local_notifications` does all of it — zero new native code

The plugin is already a dependency (step-goal notification) and its
`AndroidNotificationDetails` supports everything needed: `ongoing`,
`onlyAlertOnce`, `showWhen`/`when`, `usesChronometer`, `subText`,
`category: AndroidNotificationCategory.workout`, silent channel. The
notification half of this plan is **pure Dart**. Only the widget half has
Kotlin/XML.

## Data Contract

Same `today_snapshot` JSON as doc 24, read on Android from
`HomeWidgetPlugin` SharedPreferences
(`es.antonborri.home_widget.HomeWidgetPreferences`). Provider-side rules
are identical:

* `snapshot.date != today` → render calories as `0 / goal`
* `steps == null` (always true on Android for now) → hide the steps row
* no snapshot → `labels.noData` placeholder

## Steps on Android

`HealthService` is iOS-only today, so the snapshot's `steps` is always
`null` on Android and the widget simply doesn't render the row — the
layout is built goal-first around calories so it looks complete without
it. When Health Connect integration happens (separate roadmap-worthy item;
the `health` package already supports it), steps light up on the widget
with **no widget-side changes** — the snapshot starts carrying values.
Don't build Health Connect as part of this feature.

## Mobile (Flutter) Changes

* `widget_snapshot_controller.dart` / `widget_snapshot_writer.dart` — run
  on Android too (guard becomes `Platform.isIOS || Platform.isAndroid`).
* `WorkoutSessionNotifierService` (renamed from doc 24's
  `WorkoutLiveActivityService`) — add the Android branch:
  * `start(...)` — ensure channel + POST_NOTIFICATIONS permission (below),
    show notification id **2** (id 1 is the step-goal banner) on channel
    `workout_session`: `Importance.low`, no sound/vibration,
    `ongoing: true`, `onlyAlertOnce: true`, `autoCancel: false`.
  * `update(state)` — re-`show()` with the same id: title = session title,
    body = `exerciseName · setsDone/setsTotal`, `when` per decision #3.
  * `end()` / `endAll()` — `cancel(2)`.
* `NotificationService.init()` — currently returns early off-iOS; add
  `AndroidInitializationSettings` (small icon, see below) so the plugin is
  initialized on Android at all.
* **Notification permission**: Android 13+ needs runtime
  `POST_NOTIFICATIONS`. Request lazily via
  `requestNotificationsPermission()` the first time a workout starts (not
  at app launch — same "opt-in signal" philosophy as the iOS note in
  `NotificationService`). Denied → the service silently no-ops; the
  workout itself is unaffected.

## Android Native Changes

### Manifest / resources

* `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`
* `<receiver>` entry for `TodaySummaryWidgetProvider` with
  `APPWIDGET_UPDATE` intent-filter + `appwidget-provider` meta-data
* Monochrome small notification icon `drawable/ic_stat_lifey` (the current
  code would fall back to the launcher mipmap, which renders as a grey
  blob on the status bar)

### New files

```
android/app/src/main/kotlin/com/khunor/lifey/
  TodaySummaryWidgetProvider.kt   // AppWidgetProvider: reads snapshot, applies date rule, binds RemoteViews
android/app/src/main/res/
  layout/widget_today_summary.xml // calories value + goal + progress bar (+ steps row, gone by default)
  xml/today_summary_widget_info.xml // provider config: sizes, previewLayout, updatePeriodMillis
  values/widget_colors.xml, values-night/widget_colors.xml // app palette, light + dark
```

### Widget behavior

* **Sizes**: `minWidth/minHeight` for 2×1, resizable horizontally; one
  responsive layout (RemoteViews size-mapping from API 31, single layout
  fallback below).
* **Refresh**: `home_widget` broadcasts an update whenever Flutter writes a
  snapshot. Additionally `updatePeriodMillis = 1800000` (30 min, the OS
  minimum) so the *date rollover rule* gets applied within 30 min of
  midnight without the app opening. No AlarmManager — exact alarms need
  API 31+ permissions and midnight-accurate zeroing isn't worth that.
* **Tap**: `PendingIntent` from the package launch intent (no URL scheme
  needed on Android — `MainActivity` is `singleTop`, the launch intent
  either resumes or starts it, and `WorkoutResumePrompt` handles the
  rest).
* **Dark mode**: color resources with `values-night` variant; the provider
  layout re-inflates on `uiMode` config change automatically.

### Ongoing notification appearance

```
[ic_stat_lifey]  Push Day                    ⏱ 01:23   ← chronometer (rest count-up)
Bench Press · 2/4
Started 18:05 · 7 sets total                            ← subText
```

## Testing

* **Dart unit tests**: platform-branched service (mock
  `FlutterLocalNotificationsPlugin`): start→update→end call/argument
  sequence, `when` anchor switching (startedAt → lastSetAt), permission-
  denied no-op, orphan cancel on launch. Snapshot writer tests from doc 24
  extended with the Android/steps-null case.
* **Manual QA (emulator, API 34+)**: add widget → log meal → widget
  updates; midnight rollover via device clock; dark mode toggle; widget
  resize; deny notification permission → workout still works; start
  workout → notification appears silently; background app mid-rest →
  chronometer keeps ticking; log set → body + anchor update; swipe
  notification away (API 34) → next set brings it back; finish → gone;
  force-kill mid-workout → relaunch reattaches, or cancels if session was
  finished elsewhere; reboot mid-workout → app open recreates it; HU/EN
  labels follow in-app language.

## Implementation Order

1. **Phase A — home widget:** enable snapshot writing on Android, widget
   provider + layouts + provider-info, tap intent, dark mode. *Ship-able
   on its own; mostly free if doc 24's Dart pipeline already exists.*
2. **Phase B — ongoing notification:** Android init + icon + permission
   flow in `NotificationService`, Android branch of
   `WorkoutSessionNotifierService`, orphan handling, QA checklist.

## Future Synergies

* **Health Connect** — fills the widget's steps row with zero widget work
  (see "Steps on Android").
* **Roadmap #8 (FCM)** — same as the iOS APNs note: once push lands,
  trainer-side events can post notifications; the `workout_session`
  channel/permission groundwork is reused.
* **Android 16 "Live Updates" (`ProgressStyle`)** — a promoted, richer
  ongoing-notification surface; a drop-in upgrade of this notification
  once `flutter_local_notifications` exposes it and API 36 devices matter.
* **Roadmap #1 (configurable rest duration)** — flip the chronometer to
  `chronometerCountDown: true` with `when = lastSetAt + restDuration`;
  structural no-op, same as the iOS countdown note.
