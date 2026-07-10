# iOS Widget + Live Activity — Implementation Plan

Detailed plan for roadmap item #9 (see
[05-improvement-roadmap.md](05-improvement-roadmap.md)):

* **Home screen widget** — today's calories (vs. goal) and steps (vs. goal)
* **Live Activity** — during an active workout session: elapsed time, current
  exercise, set progress, rest timer; with Dynamic Island support

iOS only. No backend changes at all — this is purely a client feature.
Android counterpart:
[25-android-widget-ongoing-notification-plan.md](25-android-widget-ongoing-notification-plan.md)
(shares the Dart-side snapshot pipeline and service call sites planned
here).

## Scope

* Small + medium home screen widget showing today's calories and steps,
  with progress toward `dailyCalorieGoal` / `dailyStepGoal` when set
* Live Activity for an in-progress workout session, started when the
  session's timer starts and ended when the session finishes or is discarded
* Dynamic Island (compact: elapsed/rest timer; expanded: exercise + sets)
* Deep link from the widget into the app (`lifey://` scheme; the existing
  `WorkoutResumePrompt` already reopens an active session on launch, so the
  Live Activity tap needs nothing extra)
* **Not** in scope: Android home widget, push-updated Live Activities
  (needs roadmap #8 APNs infra), interactive widgets (iOS 17), watchOS

## Key Design Decisions

### 1. Data reaches the widget via an App Group snapshot, not queries

The widget extension is a separate process. It cannot use the Flutter
runtime, and reading the Drift SQLite database from Swift would couple the
extension to the app's schema for no gain. Instead the Flutter app writes a
small **snapshot** (JSON in App Group `UserDefaults`) whenever the relevant
data changes, and asks WidgetKit to reload. The widget only ever renders
the last snapshot.

Consequence: widget data is only as fresh as the last app open. That is the
same trade-off every Flutter fitness app makes, and it is acceptable here —
calories only change when the user logs a meal *in the app anyway*. Steps
do drift (they change without the app being opened); mitigation below.

### 2. `home_widget` package for the widget bridge

[`home_widget`](https://pub.dev/packages/home_widget) is the de-facto
standard bridge (saves key–values to App Group UserDefaults + triggers
`WidgetCenter.reloadTimelines`). Justification for the new dependency: the
alternative is a hand-rolled MethodChannel doing exactly what the package
does, and the package also gives us the Android bridge for free if we ever
do an Android widget. iOS-only usage; it no-ops on other platforms.

### 3. Hand-rolled MethodChannel for the Live Activity (no package)

The `live_activities` pub package exists but drags in image/App-Group
helpers we don't need and has had breaking churn. ActivityKit start/update/
end is ~80 lines of Swift in `AppDelegate` behind a `MethodChannel`
(`lifey/live_activity`), gated with `#available(iOS 16.1, *)`. Full control,
no new dependency — consistent with the "no new frameworks without
justification" rule.

### 4. Timers render natively — no updates needed while backgrounded

Both tickers in the Live Activity use SwiftUI's
`Text(timerInterval:countsDown:)`:

* elapsed workout time counts **up** from `startedAt`
* rest timer counts **up** from `lastSetAt` (mirrors the in-app rest banner,
  which also counts up since the last completed set — there is no
  configured rest duration in the current data model)

So the OS animates the timers by itself; the app only pushes an update when
the *content* changes (set logged, exercise changed, session finished) —
and all of those happen while the app is foregrounded. This is why no APNs
push channel is needed.

### 5. Deployment targets

`Runner` stays at iOS 14.0. The new `LifeyWidgets` extension target is set
to **iOS 16.1** (ActivityKit minimum). That means the home screen widget is
also 16.1+ even though WidgetKit itself would allow 14.0 — accepted
simplification: the app is unreleased ([no backward-compat constraints]),
and gating the Live Activity inside a 14.0 extension with `#available`
churn isn't worth supporting hypothetical iOS 14–16.0 devices. All
ActivityKit calls in `Runner` (AppDelegate) are `#available`-guarded.

### 6. Localization: pre-localized strings travel in the payload

The extension would otherwise need its own `Localizable.strings` in HU/EN,
duplicating ARB content — and it would follow the *system* locale while the
app has an in-app language override (`LanguagePreference`). Instead Flutter
writes already-localized display labels ("Kalória", "Lépés", "Pihenő", …)
into the snapshot / activity state using the app's own `AppLocalizations`.
The extension renders strings, it never translates. Numbers/dates are
formatted in Swift with the locale identifier passed in the payload.

## Data Contracts

### Widget snapshot (App Group UserDefaults, key `today_snapshot`)

```json
{
  "date": "2026-07-10",           // local calendar day the values belong to
  "updatedAtEpochMs": 1783075200000,
  "calories": 1430,                // rounded kcal, from dashboard aggregation
  "calorieGoal": 2200,             // null when no goal set
  "steps": 6412,                   // null when Health not connected
  "stepGoal": 10000,               // null when no goal set
  "locale": "hu",
  "labels": { "calories": "Kalória", "steps": "Lépés", "noData": "Nyisd meg az appot" }
}
```

Rules the Swift `TimelineProvider` applies:

* `snapshot.date != today` → the day rolled over with the app closed:
  render calories as `0 / goal` (nothing logged today is a true statement)
  and steps as `—` (unknown, Health-owned). The timeline always schedules
  one extra entry at the **next midnight** so this switch happens on time
  without any app involvement.
* `steps == null` → hide the steps row / show placeholder.
* No snapshot at all (fresh install, never opened) → `noData` placeholder.

### Live Activity (`WorkoutActivityAttributes`)

Shared Swift file compiled into **both** targets (Runner + LifeyWidgets):

```swift
struct WorkoutActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var exerciseName: String     // current (last touched) exercise, pre-localized fallback for empty
    var setsDone: Int            // sets completed in current exercise
    var setsTotal: Int?          // targetSets, nil for free-form blocks
    var totalSetsDone: Int       // whole session
    var lastSetAtEpochMs: Int64? // rest timer anchor; nil before first set
  }
  var sessionClientId: String
  var title: String              // template name or localized "Edzés"
  var startedAtEpochMs: Int64
}
```

MethodChannel API (all no-op below iOS 16.1 / when
`ActivityAuthorizationInfo().areActivitiesEnabled` is false):

* `start(attributes, initialState) -> activityId?`
* `update(state)` — finds the activity by `sessionClientId`
* `end()` — `.end(dismissalPolicy: .immediate)`
* `endAll()` — safety sweep for orphans (called on app start)

## Mobile (Flutter) Changes

### New: `lib/core/home_screen_widget/`

* `widget_snapshot_writer.dart` — plain class: builds the snapshot JSON from
  `DailyStats` + steps + `UserSettings`, calls
  `HomeWidget.saveWidgetData` / `HomeWidget.updateWidget`. Unit-testable by
  injecting the `home_widget` calls.
* `widget_snapshot_controller.dart` — Riverpod `Provider` that `ref.listen`s
  `dashboardControllerProvider` (calories), `todayStepsControllerProvider`
  and `settingsControllerProvider` (goals + language), debounces (~2 s) and
  writes the snapshot. Registered at app root the same way
  `connectivitySyncControllerProvider` is (watched once in `main.dart` /
  bootstrap). Also writes once on `AppLifecycleState.paused` so the very
  last state before backgrounding is always captured.

No-ops on non-iOS, same pattern as `NotificationService` / `HealthService`.

### New: `lib/core/live_activity/workout_live_activity_service.dart`

Thin wrapper over the `lifey/live_activity` MethodChannel with the four
calls above, exposed via a Riverpod provider. No-ops on non-iOS.

### `LogSessionScreen` wiring (the only screen that touches it)

The screen already has exactly the right lifecycle hooks:

| Existing hook | Live Activity call |
|---|---|
| ticker start in `_persist()` (first set of a new session) | `start(...)` |
| ticker start in `_startScheduledSession()` | `start(...)` |
| ticker start in `initState` for resumed in-progress session | `start(...)` if none exists (re-attach after process death) |
| set row checked/unchecked, exercise added, `_autoSave` | `update(...)` (derive state from `_blocks`; debounce with the existing autosave path) |
| finish button → `_finishedAt` set | `end()` |
| session deleted / discarded | `end()` |

"Current exercise" = the block whose set was most recently marked done
(falls back to the first block with remaining sets).

### Orphan handling

If the OS kills the app mid-workout the activity survives. Two guards:

* every `start`/`update` sets `staleDate = now + 4h`, so an abandoned
  activity visibly greys out and iOS may remove it
* on app start, after `WorkoutResumePrompt` resolves: if an in-progress
  session exists → `start()` re-attaches (ActivityKit returns existing
  activities via `Activity<WorkoutActivityAttributes>.activities`);
  if none exists → `endAll()`

### Deep link

Add `lifey` to `CFBundleURLTypes` (next to the existing Google scheme).
Widget sets `widgetURL(URL(string: "lifey://today"))`. Phase 1 handling:
opening the app is enough (dashboard is the home route); no new go_router
plumbing beyond accepting the scheme. Live Activity tap just opens the app
— `WorkoutResumePrompt` / the still-mounted `LogSessionScreen` already
handle the rest.

## iOS Native Changes

### Xcode project (manual, on a Mac — see Constraints)

1. Apple Developer portal: register App Group `group.com.khunor.lifey`,
   add it to the `com.khunor.lifey` app ID and to a new
   `com.khunor.lifey.LifeyWidgets` extension ID.
2. New target: **Widget Extension** `LifeyWidgets` ("Include Live
   Activity" checked, no configuration intent), deployment target 16.1,
   embedded in Runner.
3. App Groups capability (`group.com.khunor.lifey`) on **both** targets —
   `Runner.entitlements` keeps its HealthKit entries.
4. `Runner/Info.plist`: `NSSupportsLiveActivities = YES`, add `lifey` URL
   scheme.
5. `home_widget` pod lands via the normal `pod install`.

### New Swift files

```
ios/LifeyWidgets/
  LifeyWidgetsBundle.swift      // @main WidgetBundle: TodaySummaryWidget + WorkoutLiveActivity
  TodaySummaryWidget.swift      // TimelineProvider (reads snapshot) + small/medium views
  WorkoutLiveActivity.swift     // lock-screen view + Dynamic Island (compact/minimal/expanded)
ios/Shared/
  WorkoutActivityAttributes.swift  // target membership: Runner + LifeyWidgets
ios/Runner/
  LiveActivityChannel.swift     // MethodChannel handler, registered in AppDelegate
```

### Widget UI

* **Small**: calories ring (progress vs. goal; plain number when no goal),
  steps line under it.
* **Medium**: two stat tiles side by side (calories + goal, steps + goal),
  matching the dashboard's card look — colors hardcoded to the app palette
  (`app_tokens.dart` values transcribed), light + dark variants via
  `@Environment(\.colorScheme)`.
* Timeline: `[entry(now), entry(nextMidnight)]`, policy `.atEnd`.

### Live Activity UI

* **Lock screen**: title row (template name + elapsed `Text(timerInterval:)`),
  current exercise + `setsDone/setsTotal`, rest count-up timer with icon
  (hidden before the first set).
* **Dynamic Island** — expanded: leading = elapsed, trailing = rest timer,
  bottom = exercise + set progress; compact: dumbbell glyph + rest timer;
  minimal: dumbbell glyph.
* Live Activities auto-end after 8 h of activity by the OS — fine for
  workouts; `staleDate` guards the abandoned case sooner.

## Steps Freshness (known limitation + follow-up option)

With the snapshot approach, steps shown on the widget freeze at the last
app open. Acceptable for v1 (show data as-is; the `date` rollover rule
prevents *wrong* data, only *stale-same-day* data is possible).

**Phase 2b (optional):** query HealthKit directly in the widget's
`TimelineProvider` (`HKStatisticsQuery` for today's `stepCount`;
authorization is shared with the app, the extension target gets the
HealthKit entitlement). WidgetKit's refresh budget (~40–70 reloads/day)
then bounds staleness at roughly 15–30 min instead of "since last open".
Kept out of v1 because it adds entitlement + async-timeline complexity and
the calories number can't get the same treatment anyway (it lives in the
app's local DB).

## Constraints / Build Environment

* The Xcode target + entitlements work (and any Swift compilation)
  **requires macOS**; it cannot be done or verified from the Windows dev
  environment. Plan the work in two chunks: all Dart-side code (snapshot
  writer, service, LogSessionScreen wiring, tests) is platform-neutral and
  can be built/tested anywhere; the native chunk is a Mac session.
* Simulator support: widgets work on any iOS 16.1+ sim; Live Activities
  need sim iOS 16.2+ (Dynamic Island: pick an iPhone 15/16 Pro sim).
* CI/`flutter test` is untouched — all new Dart code no-ops off-iOS.

## Testing

* **Dart unit tests**: snapshot building (goal null-ness, day string, label
  localization, steps-null case); Live Activity service call sequence from
  a scripted LogSessionScreen flow (mock MethodChannel via
  `TestDefaultBinaryMessenger`).
* **Manual QA checklist (device)**: add widget → log a meal → widget
  updates within seconds of backgrounding; midnight rollover (set device
  clock); no-goal and no-Health states; start workout → activity appears;
  log sets → island updates; lock phone mid-rest → rest timer keeps
  ticking; finish → activity ends; force-kill mid-workout → relaunch
  re-attaches; discard workout → activity ends; HU/EN labels follow the
  in-app language setting.

## Implementation Order

1. **Phase 0 — native scaffolding (Mac):** App Group, extension target,
   entitlements, `NSSupportsLiveActivities`, `lifey://` scheme, empty
   widget renders "no data". Windows-side prep done (Info.plist,
   entitlements, placeholder widget source); Xcode target creation is
   still a Mac session — see the Phase 0 checklist below.
2. **Phase 1 — home widget:** `home_widget` dep, snapshot writer +
   controller, `TodaySummaryWidget` small/medium, midnight + stale rules,
   deep link. *Ship-able on its own.* **Dart side done** (writer,
   controller, app.dart wiring, unit tests, l10n keys — all pass on
   Windows). `TodaySummaryWidget.swift` has the real small/medium UI
   written (reads the App Group snapshot, midnight-rollover + no-snapshot
   rules, `widgetURL`), but it's unbuilt/unverified until the Mac session
   creates the `LifeyWidgets` target (Phase 0) and can actually compile
   and run it.
3. **Phase 2 — Live Activity:** attributes + channel + service,
   LogSessionScreen wiring, lock-screen + Dynamic Island UI, orphan
   handling. **Dart side done**: `WorkoutLiveActivityService`
   (start/update/end/endAll over `lifey/live_activity`, unit-tested with
   `TestDefaultBinaryMessengerBinding`), all six `LogSessionScreen` hook
   points wired (first-set start, scheduled-session start, resume
   re-attach in `initState`, autosave → update via `_persist`, finish →
   end in `_persistFinished`), the delete-while-in-progress case in
   `sessions_tab.dart`, and the `endAll()` orphan sweep in
   `WorkoutResumePrompt`. Native Swift written (`WorkoutActivityAttributes`,
   `LiveActivityChannel`, `WorkoutLiveActivity` lock-screen + Dynamic
   Island UI) but unbuilt/unverified until the Mac session — see the
   Phase 2 checklist below.
4. **Phase 2b (optional):** HealthKit steps query inside the widget
   extension.

### Phase 0 checklist (Mac session)

Windows-side prep already done: `Info.plist` has `NSSupportsLiveActivities`
+ the `lifey` URL scheme, `Runner.entitlements` has the
`com.apple.security.application-groups` key (value
`group.com.khunor.lifey`), and `ios/LifeyWidgets/LifeyWidgetsBundle.swift`
+ `TodaySummaryWidget.swift` exist as a placeholder "no data" widget ready
to be dropped into a new target. None of this is wired into the Xcode
project yet — that part needs Xcode:

1. Apple Developer portal → Identifiers → App Groups: register
   `group.com.khunor.lifey`. Add it to the `com.khunor.lifey` app ID.
   Register a new explicit App ID `com.khunor.lifey.LifeyWidgets` for the
   extension and add the same App Group to it.
2. Xcode → File → New → Target → **Widget Extension**, product name
   `LifeyWidgets`, check "Include Live Activity", uncheck "Include
   Configuration Intent". Deployment target **16.1**. When Xcode asks to
   activate the scheme, yes.
3. Xcode will generate its own `LifeyWidgetsBundle.swift` /
   `<Name>Widget.swift` — delete those and instead add the existing
   `ios/LifeyWidgets/LifeyWidgetsBundle.swift` and `TodaySummaryWidget.swift`
   to the `LifeyWidgets` target (right-click group → Add Files, make sure
   target membership is `LifeyWidgets` only).
4. Signing & Capabilities: add **App Groups** capability to both `Runner`
   and `LifeyWidgets` targets, tick `group.com.khunor.lifey` on both (Xcode
   syncs this into each target's `.entitlements`; `Runner.entitlements` in
   this repo already has the key pre-filled so it should just tick itself).
5. `pod install` from `mobile/ios/` (needed once the `home_widget` dep is
   added in Phase 1 — harmless to run now too).
6. Build & run on an iOS 16.1+ simulator/device. Long-press home screen →
   add widget → "Lifey" → should show the "Nyisd meg az appot" small/medium
   placeholder. That's the Phase 0 acceptance bar.
7. Confirm the app still launches normally and `lifey://` opens it (Safari
   address bar on the simulator, or `xcrun simctl openurl booted
   lifey://today`).

Commit the resulting `.xcodeproj` / `.pbxproj` and any new `.entitlements`
changes from that Mac session — those are binary/generated-by-Xcode files
that can't be produced from Windows.

### Phase 2 checklist (Mac session)

Windows-side prep already done: `ios/Shared/WorkoutActivityAttributes.swift`
(the shared attributes/content-state struct), `ios/Runner/LiveActivityChannel.swift`
(the `lifey/live_activity` MethodChannel handler, registered in
`AppDelegate.swift`), and `ios/LifeyWidgets/WorkoutLiveActivity.swift`
(lock-screen + Dynamic Island UI, already added to `LifeyWidgetsBundle`)
all exist as source. None of it has target membership yet:

1. Add `ios/Shared/WorkoutActivityAttributes.swift` to **both** the
   `Runner` and `LifeyWidgets` target membership (select the file →
   File Inspector → Target Membership).
2. Confirm `ios/Runner/LiveActivityChannel.swift` picked up `Runner`
   target membership (it's inside `ios/Runner/`, so Xcode's "Add Files"
   during the Phase 0 pass should have caught it if added then — check
   and fix membership if not).
3. Confirm `ios/LifeyWidgets/WorkoutLiveActivity.swift` has `LifeyWidgets`
   target membership (same caveat — if it was written after the Phase 0
   "Add Files" pass, add it manually now).
4. `LiveActivityChannel.swift` is gated at iOS 16.2 (`ActivityContent`'s
   `staleDate` needs it, see the file's header comment) even though the
   plan's headline minimum is 16.1 — no action needed, just don't be
   surprised the availability checks say 16.2 in that one file.
5. Build & run on an iOS 16.2+ simulator — Live Activities need 16.2 (per
   Constraints above); pick an iPhone 15/16 Pro sim for Dynamic Island.
6. Manual QA per the Testing section: start a workout → activity appears
   on lock screen + Dynamic Island; log sets → progress/exercise updates;
   lock the phone mid-rest → rest timer keeps ticking natively; finish →
   activity ends; force-kill mid-workout → relaunch re-attaches (not a
   duplicate); swipe-delete an in-progress session from Sessions → activity
   ends; leave the app fully closed with nothing in progress → cold
   relaunch sweeps any orphan via `endAll()`.

## Future Synergies

* Roadmap #8 (APNs): once push infra exists, Live Activities can be updated
  remotely via their push token (e.g. trainer comment mid-workout).
* Roadmap #6 (remaining budget): the snapshot already carries goal +
  consumed — a "remaining kcal" widget variant is a view-only change.
* Roadmap #1 (configurable rest duration): if a rest *target* is added
  later, the Live Activity rest timer flips from count-up to countdown
  (`countsDown: true`) with no structural change.
