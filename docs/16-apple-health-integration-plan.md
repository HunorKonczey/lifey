# 16 – Apple Health integration

Status: proposed
Author: planning doc (implement in phases, in order)
Platform: **iOS only** — Apple Health/HealthKit has no Android equivalent. Android
would need a separate Health Connect track (out of scope here). Everything below
must be feature-gated to iOS (`Platform.isIOS`) so the app keeps building/running
on Android with the integration simply absent.

## 1. Reality check — read this first

The single most important constraint, the same kind of "the data isn't exposed"
wall we hit with per-set workout data:

**HealthKit gives third-party apps no real-time "another app started a workout"
event.** Apple's Fitness/Watch app writes the `HKWorkout` sample to HealthKit
when the workout **ends** (is saved), not when the user taps Start. You cannot
observe Apple's in-progress `HKWorkoutSession` from your iOS app — that API only
covers sessions *your own* app/extension owns. `HKObserverQuery` +
`enableBackgroundDelivery` on the workout type wakes you when a workout sample is
**written**, i.e. at completion.

What this means for the desired flow ("start in Fitness → instant notification →
I start mine too → it closes when Fitness closes → import calories"):

- The **live, concurrent** version is not achievable with public APIs.
- The **achievable** version is: we get woken **when the Fitness strength workout
  finishes and syncs**, fire a notification *then*, and tapping it imports the
  already-finished workout (start/end time + active calories) into a saved
  session. Same end value (a session in your app with Apple's calories), just the
  notification lands at completion, not at start.

This plan is designed around the achievable version. The notification copy should
say "detected/completed", not "started". If real-time start detection is a hard
requirement, the only path is a companion **watchOS app** that runs its own
`HKWorkoutSession` — a much larger project, noted but not planned here.

## 2. Complexity at a glance

| Phase | What | BE work | Mobile work | Difficulty |
|------|------|---------|-------------|-----------|
| 0 | HealthKit foundation (entitlement, permissions) | none | setup + Dart permission flow | Low–Med |
| 1 | Strength-workout completion → notify → pair with active session (calories + avg HR), Apple badge | small (3 columns) | **native Swift** (observer/background) + notification + pairing | **High** |
| 2 | Step count on dashboard, ~1 min refresh while active | none | Dart foreground read + timer | Low–Med |
| 3 | Weight sync from Health, 30-min dedup | none | Dart read + dedup, reuse weight path | Med |

The bulk is mobile. The only genuinely hard part is Phase 1's background/native
plumbing; Phases 2 and 3 are Dart-only foreground reads via the `health` package.

---

## Phase 0 — HealthKit foundation (prerequisite for 1 & 3; nice-to-have for 2)

### Goal
The app can request and hold HealthKit read permission for the types we need
(workouts + active energy for Phase 1, steps for Phase 2, body mass for Phase 3),
on iOS only, without breaking Android.

### Design
- Add the `health` package (pub.dev) for Dart-side foreground reads, and (for
  Phase 1) plan on `flutter_local_notifications` later.
- iOS native setup: enable the HealthKit capability on the Runner target, add
  `NSHealthShareUsageDescription` (read) to `Info.plist`. We only read, so no
  `NSHealthUpdateUsageDescription` unless we later write back.
- A single `HealthService` (under `lib/core/health/`) wraps the package, exposes
  `isAvailable`, `requestPermissions()`, and typed read helpers. All callers go
  through it; everything no-ops and returns empty on non-iOS.
- A settings toggle "Connect Apple Health" (reuse the existing settings module)
  gates whether we read at all, so the user opts in.

### Status: ✅ implemented
- `health: 13.0.0` added to pubspec (pinned at 13.x; its transitive deps only
  downgrade the unused Windows-desktop packages).
- `lib/core/health/health_service.dart` (`HealthService` + `healthServiceProvider`),
  `health_preferences.dart` (device-local opt-in via secure storage),
  `health_controller.dart` (`appleHealthControllerProvider` — toggle that fires
  `requestPermissions` on enable). All iOS-gated; no-op on Android.
- Settings screen: iOS-only "Apple Health" section with a "Connect Apple Health"
  switch (`_AppleHealthToggle`), saving immediately (not part of the form).
- iOS native: `NSHealthShareUsageDescription` in Info.plist, `Runner.entitlements`
  with the HealthKit entitlement, `CODE_SIGN_ENTITLEMENTS` wired into all three
  Runner build configs in project.pbxproj.

**Manual Xcode/macOS steps still required (can't be done from a non-Mac dev box):**
1. This project currently has **no `ios/Podfile`** — every plugin added so far
   ships a Swift Package Manager `Package.swift`
   (`ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift`
   is the proof: empty `dependencies: []`). `health` 13.0.0 is the **first**
   CocoaPods-only plugin (its `ios/` only has a `.podspec`, no `Package.swift`).
   On the Mac, run:
   ```
   cd mobile
   flutter clean
   flutter pub get
   flutter build ios --no-codesign
   ```
   `flutter build ios` detects the CocoaPods-only plugin and **auto-generates
   `ios/Podfile`**, then runs `pod install` as part of the build. Building once
   from Xcode (`Runner.xcworkspace`, Cmd+B) does the same via its Flutter build
   phase. Do **not** run `pod install` manually before this — there's nothing for
   it to install against yet.
2. Open `ios/Runner.xcworkspace` in Xcode → Runner target → Signing &
   Capabilities → **+ Capability → HealthKit** (registers the App ID for
   HealthKit on the developer portal / provisioning profile; the entitlements
   file and build setting are already in place from Prompt 0.1).
3. Verify on a real device (HealthKit isn't fully functional in the Simulator).

### Prompt 0.1 — foundation + permissions
```
Read mobile/pubspec.yaml, mobile/lib/core/ structure, and the settings feature
(lib/features/settings or wherever user settings live) to match conventions.

Add an iOS-only Apple HealthKit foundation:
1. Add the `health` package to pubspec.yaml.
2. iOS native config: enable HealthKit capability on the Runner target and add
   NSHealthShareUsageDescription to ios/Runner/Info.plist with a clear purpose
   string. (Document the manual Xcode capability step in a comment / the PR.)
3. Create lib/core/health/health_service.dart: a HealthService class wrapping the
   health package. Expose `bool get isAvailable` (false on non-iOS),
   `Future<bool> requestPermissions(List<HealthDataType> types)`, and leave room
   for typed read helpers added in later phases. Everything must no-op safely on
   Android (guard with Platform.isIOS) so the app still builds and runs there.
4. Expose it via a Riverpod provider (healthServiceProvider) following the
   existing provider conventions.
5. Add a user-facing "Connect Apple Health" opt-in toggle in settings that, when
   enabled, triggers requestPermissions for the union of types used by the
   enabled phases. Persist the toggle like other settings.
Do not implement workout/step/weight reads yet — just the plumbing + permission
request. Keep four-layer conventions; run build_runner if a @riverpod provider
was added.
```

---

## Phase 1 — Strength-workout completion → notification → pair with active session

### Goal
When a Traditional/Functional Strength workout finishes in Apple Fitness and syncs
to HealthKit, the app:
1. Posts a local notification that a workout ended.
2. **Only when the user taps the notification**, it looks for an **in-progress**
   session (`finishedAt == null`) whose `startedAt` is **within ±15 minutes** of
   the Apple workout's start, and shows a **confirmation dialog** ("Pair this
   Apple workout with your active session? Calories X, avg HR Y") describing the
   match.
3. **Only if the user accepts**, it **pairs them**: writes the Apple workout's
   **active calories** and **average heart rate** onto that session, sets its
   `finishedAt` to the Apple workout's end time (closing it), and tags it with the
   Apple workout's id so it's recognizable as imported.
4. Paired sessions show a small **Apple logo** in the sessions list, so it's
   obvious an import happened.

Nothing is closed or modified automatically — detection only posts a notification;
pairing always requires an explicit tap + accept. This is the no-watchOS,
pair-on-completion design the user chose. It works because by the time HealthKit
hands us the finished workout, the user's own session is still open (in progress)
— we match on start time and, on confirmation, close it with Apple's data.

### Matching rules (be explicit)
- Trigger: notification tap → confirmation dialog → accept. Never automatic.
- Candidates: sessions with `finishedAt == null` (in progress).
- Window: `|session.startedAt − hkWorkout.startDate| ≤ 15 min`.
- If several candidates fall in the window, pick the **closest** start time.
- If **no** candidate matches: do **nothing** (just keep the "workout ended"
  notification). No standalone import — confirmed out of scope for now.
- Dedup: never pair the same HKWorkout twice — `healthWorkoutId` on the session
  (and a locally-persisted set of seen UUIDs) guards this.

### Imported fields → new columns
Three nullable fields, added end-to-end exactly like `performedAt` in doc 15:
- `activeCalories` (double) — active energy burned, kcal.
- `averageHeartRate` (double) — bpm over the workout interval.
- `healthWorkoutId` (string) — the HKWorkout UUID. **Non-null ⇒ imported**, which
  drives both the Apple-logo badge and dedup. A convenience getter
  `bool get fromAppleHealth => healthWorkoutId != null` feeds the UI.

### Backend work (small — three nullable columns)
- `WorkoutSession` entity + `active_calories`, `average_heart_rate`,
  `health_workout_id` columns (all nullable); request + response fields; mapper;
  service set-from-request on create and update.
- Flyway `V15__workout_session_health_fields.sql`: add the three nullable columns
  (no backfill — old sessions stay null).
- Tests updated for the new nullable fields (including null case).

### Mobile work (the hard part)
- **Native Swift**: `HKObserverQuery` on `HKWorkoutType` with
  `enableBackgroundDelivery(.immediate)`, filtered to functional/traditional
  strength training. On a newly-saved workout, collect `uuid`, `startDate`,
  `endDate`, `duration`, total `activeEnergyBurned` (kcal), and **average heart
  rate** (query `HKQuantityType.heartRate` over the workout interval, or
  `HKWorkout`'s heart-rate statistics). Bridge to Dart via a channel registered in
  `AppDelegate` so it fires when backgrounded.
- `flutter_local_notifications`: post the "workout ended" notification; the tap
  routes (go_router) into the app carrying the workout payload.
- Pairing service (`lib/core/health/`): triggered **on notification tap**. It runs
  the matching rules, shows a confirmation dialog, and **only on accept**
  closes+enriches the session through the existing `WorkoutSessionRepository.update`
  (offline-first; it syncs normally). Detection alone never modifies data.
- Drift: add the three nullable columns to the workout_sessions table + schema
  bump, carried through domain/repo/payload/pull_engine (doc 15 pattern).

### Prompt 1.1 — backend health fields (calories, avg HR, workout id)
```
Read backend/src/main/java/com/lifey/workout/session/{WorkoutSession.java,
WorkoutSessionServiceImpl.java,WorkoutSessionMapper.java,
dto/WorkoutSessionRequest.java,dto/WorkoutSessionResponse.java}, the latest
Flyway migration, and the session tests.

Add three nullable fields to workout sessions end-to-end, for Apple Health import:
- activeCalories (Double) -> column active_calories
- averageHeartRate (Double) -> column average_heart_rate
- healthWorkoutId (String) -> column health_workout_id
All nullable. Add them to the entity, WorkoutSessionRequest and
WorkoutSessionResponse (nullable; optional positivity validation on the numbers),
mapper population, and service set-from-request on create AND update. Add Flyway
V15__workout_session_health_fields.sql adding the three nullable columns (no
backfill). Update WorkoutSessionServiceImpl and controller tests to round-trip
the fields including the all-null case. Java 24, Maven, constructor injection;
the Service interface already exists.
```

### Prompt 1.2 — mobile data/sync for the health fields
```
Read mobile/lib/core/local_db/tables/workout_session_tables.dart,
app_database.dart, lib/features/workouts/domain/workout_session.dart,
data/workout_session_repository.dart, and core/sync/pull_engine.dart
(_pullWorkoutSessions).

Thread three nullable fields through the workout-session stack, mirroring how
performedAt was added (doc 15): activeCalories (double?), averageHeartRate
(double?), healthWorkoutId (String?). Add nullable Drift columns + schema bump
(no backfill); add the fields to domain WorkoutSession plus a convenience getter
`bool get fromAppleHealth => healthWorkoutId != null`; read them in the repository
and include them in the request payload only when non-null; read them in
pull_engine. ExerciseSetInput/sets are unaffected. Regenerate Drift code. Don't
touch UI yet.
```

### Prompt 1.3 — iOS native workout observer (calories + avg HR) + notification
```
Implement the iOS-only HealthKit workout observer.

Native (ios/Runner, Swift): set up an HKObserverQuery on HKWorkoutType with
background delivery (.immediate), filtered to traditional/functional strength
training. On a newly-saved workout, collect uuid, startDate, endDate, duration,
total activeEnergyBurned (kcal), and average heart rate over the workout interval
(query HKQuantityType.heartRate within [startDate,endDate] and average, or use the
workout's heart-rate statistics). Bridge results to Dart via a MethodChannel/
EventChannel registered in AppDelegate so it fires when backgrounded.

Dart: add flutter_local_notifications. In a HealthWorkoutObserver service
(lib/core/health/), listen to the channel, dedup by HKWorkout uuid against a
locally-persisted set, and post a local notification that a strength workout
ended in Apple Fitness, carrying the payload (uuid, start, end, calories, avg HR)
in the notification payload. Detection must NOT modify any data — it only posts
the notification. Wire the notification tap through go_router to a pairing entry
point (handled in prompt 1.4), passing the payload along. Guard everything with
Platform.isIOS. Document the required Xcode background-mode / capability steps.
```

### Status: ✅ implemented
- `ios/Runner/HealthWorkoutObserver.swift`: `HKObserverQuery` on `HKObjectType.workoutType()`
  with `enableBackgroundDelivery(for:frequency:.immediate)`; on fire, re-queries the 20 most
  recent traditional/functional strength `HKWorkout`s, skips any UUID already recorded in
  `UserDefaults` (HealthKit re-delivers the whole set on every fire, not just the new one), and
  for each new one fans out two `HKStatisticsQuery`s (active energy `.cumulativeSum`, heart rate
  `.discreteAverage`) before pushing `{uuid, startDate, endDate, activeCalories,
  averageHeartRate}` through a `FlutterEventChannel` (`com.lifey.health/workout_events`).
- `AppDelegate.swift`: registers a throwaway plugin registrar (`HealthWorkoutObserverPlugin`) in
  `didInitializeImplicitFlutterEngine` purely to obtain a `FlutterBinaryMessenger`, then keeps a
  strong reference to `HealthWorkoutObserver` for the app's lifetime.
- `ios/Runner.xcodeproj/project.pbxproj`: `HealthWorkoutObserver.swift` wired into the `Runner`
  group and `Sources` build phase (this project has no Xcode "file system synchronized group",
  so new files need an explicit pbxproj entry — same as Phase 0's entitlements wiring).
- `lib/core/health/health_workout_observer.dart` (`HealthWorkoutObserverService` +
  `healthWorkoutObserverServiceProvider`): listens to the event channel (iOS-only — no-ops via
  `Platform.isIOS` otherwise), dedups by UUID against a `flutter_secure_storage`-persisted list
  (capped at 200, independent of the native-side dedup — defense in depth), and — only if the
  "Connect Apple Health" toggle is on — posts a local notification via
  `flutter_local_notifications`, JSON-encoding the event into the notification `payload`.
  Exposes `onWorkoutNotificationTapped`, a callback hook prompt 1.4's pairing flow attaches to
  (set via `FlutterLocalNotificationsPlugin.initialize`'s `onDidReceiveNotificationResponse`).
  Never writes to the local DB or backend — detection is read-only, as required.
- Started once for the app's lifetime from `app.dart`, alongside
  `connectivitySyncControllerProvider` (`ref.watch(healthWorkoutObserverServiceProvider)`).
- `flutter_local_notifications: ^19.4.2` added to `pubspec.yaml` (resolved to 19.5.0).

**Manual Xcode/macOS steps still required (can't be done from a non-Mac dev box):**
1. `flutter_local_notifications` is a new plugin dependency — on the Mac, re-run
   `cd mobile && flutter clean && flutter pub get && flutter build ios --no-codesign` (or build
   once from Xcode) so CocoaPods picks it up in the already-generated `Podfile` (see Phase 0).
2. Open `ios/Runner.xcworkspace` in Xcode and confirm `HealthWorkoutObserver.swift` shows up
   under the `Runner` group (it's wired into `project.pbxproj` already, but Xcode should be
   opened once to confirm the project file parses cleanly after a hand-edit).
3. No new capability or `UIBackgroundModes` entry is needed beyond Phase 0's HealthKit
   capability — `enableBackgroundDelivery` uses HealthKit's own background-wake mechanism, not
   the generic background-fetch/remote-notification modes. Re-verify the HealthKit capability is
   still checked under Signing & Capabilities (Phase 0, step 2) after the pbxproj hand-edit.
4. Verify on a **real device** — both `enableBackgroundDelivery` and local-notification delivery
   are unreliable/unsupported in the Simulator. To test: log a Traditional or Functional Strength
   workout in Apple Fitness (or Health app, "Add Data" → Workouts) on the device, background the
   Lifey app, and confirm a "Strength workout detected" notification appears once HealthKit syncs
   the sample (this can take anywhere from seconds to a few minutes — it's Apple's sync, not
   ours).

### Prompt 1.4 — pairing on notification tap (confirm, then close + enrich)
```
Read mobile/lib/features/workouts/domain/workout_session.dart,
data/workout_session_repository.dart, application/workout_session_controller.dart,
the go_router setup, and the HealthWorkoutObserver payload from prompt 1.3.

Add pairing that runs ONLY when the user taps the "workout ended" notification —
detection itself must never modify data:
- On tap, route into the app with the HKWorkout payload.
- Find the best in-progress session (finishedAt == null) with
  |session.startedAt - hkWorkout.startDate| <= 15 minutes; if several match, pick
  the closest start time.
- If a candidate is found, show a confirmation dialog summarizing the match
  (session start, Apple calories, avg HR) asking the user to confirm pairing.
- ONLY on accept: update that session via WorkoutSessionRepository.update, setting
  finishedAt = hkWorkout.endDate, activeCalories, averageHeartRate, and
  healthWorkoutId = hkWorkout.uuid (keep its existing sets/planned exercises).
  Record the uuid as imported so the same HKWorkout can't pair twice.
- If no candidate matches, just show a brief "no matching active workout" message
  and do nothing else (no standalone import — out of scope).
Add localized strings for the dialog/messages (app_en.arb/app_hu.arb). iOS-only.
```

### Status: ✅ implemented
- `rootNavigatorKey` added to `app_router.dart` (passed as GoRouter's `navigatorKey:`), giving
  code outside the widget tree — the notification-tap handler — a `BuildContext` to show dialogs
  with. The existing screens still navigate via plain `Navigator.push`/`MaterialPageRoute`, so
  this is the minimal hook needed rather than a new routed page.
- `lib/core/health/health_workout_pairing_service.dart` (`HealthWorkoutPairingService` +
  `healthWorkoutPairingServiceProvider`): wired to
  `HealthWorkoutObserverService.onWorkoutNotificationTapped` from `app.dart`, so it only runs on
  an explicit notification tap. On `handle(event)`:
  1. Reads the current session list from `workoutSessionControllerProvider` (no extra DB query).
  2. Skips entirely if any session already carries this `healthWorkoutId` (re-tapping a
     still-visible notification can't pair the same HKWorkout twice).
  3. Picks the closest in-progress (`finishedAt == null`) session within ±15 minutes of the
     workout's start; shows `noMatchingActiveWorkoutMessage` via SnackBar and stops if none.
  4. Shows a confirmation `AlertDialog` (`pairAppleWorkoutTitle`/`pairAppleWorkoutMessage`,
     formatted start time + rounded calories/avg HR) — Cancel vs Pair.
  5. Only on Pair: calls `WorkoutSessionRepository.update` with the session's existing
     `exerciseClientIds`/`sets` unchanged, plus `finishedAt = event.endDate`, `activeCalories`,
     `averageHeartRate`, `healthWorkoutId = event.uuid` — closing and enriching it in one write.
- Localized strings added to both `app_en.arb` and `app_hu.arb`
  (`pairAppleWorkoutTitle/Message`, `pairButton`, `noMatchingActiveWorkoutMessage`); regenerated
  via the Flutter tool snapshot (`flutter gen-l10n`, see the `dart`/`flutter` SDK-lock workaround
  note above).

### Prompt 1.5 — Apple-logo badge in the sessions list
```
Read mobile/lib/features/workouts/presentation/sessions_tab.dart (the _SessionCard
header Row around the date/in-progress chip).

When session.fromAppleHealth is true, show a small Apple logo next to the date in
the session card header, so paired/imported workouts are visibly marked. Use an
appropriate icon (e.g. Icons.apple) at label size with a tooltip/semantics label
like "Imported from Apple Health" (add localized strings to app_en.arb/app_hu.arb).
Optionally surface activeCalories / averageHeartRate in the card body when present.
Keep the existing layout, in-progress chip, sync indicator, and delete affordances
intact.
```

### Status: ✅ implemented
- `sessions_tab.dart`'s `_SessionCard` header `Row`: a small `Icons.apple` (16px,
  `onSurfaceVariant`) next to the date, shown only `if (session.fromAppleHealth)`, with a
  `Tooltip` + `semanticLabel` using the new `importedFromAppleHealthTooltip` string. Existing
  in-progress chip, sets-count text, sync indicator, and delete button are untouched.
- Card body: when `activeCalories` or `averageHeartRate` is non-null, a small
  `appleHealthStatsLine` ("{calories} kcal · {heartRate} bpm avg (Apple Health)") row appears
  between the header and the logged-sets list.
- Localized strings added to both arb files; Phase 1 is now fully implemented end-to-end (backend
  columns → mobile sync → native detection → notification → confirm-pair → badge).

---

## Phase 2 — Step count on the dashboard

### Goal
Show today's step count (from HealthKit) on the dashboard, refreshing about once a
minute while the app is in the foreground.

### Design (mobile only — no backend, no sync)
Steps are device/health-owned, change constantly, and old values don't matter, so
treat them as a **read-through display**, never persisted or synced. This keeps it
offline-friendly (it's a local HealthKit read) and avoids polluting the backend.

- `HealthService.todaySteps()` reads `HKQuantityType.stepCount` summed for the
  current day (iOS only; returns null on Android / no permission).
- A Riverpod provider exposes it, re-querying every ~60s while foregrounded
  (Timer.periodic started on resume, cancelled on pause via AppLifecycleState) —
  do not poll in the background.
- Add a steps `StatCard` to the dashboard next to the existing stats. Hide the
  card entirely when steps are unavailable (Android, or permission denied) so the
  dashboard degrades cleanly. Note: `dashboardControllerProvider` is a pure
  derived Provider today — add steps as a separate watched provider so its 60s
  refresh doesn't force-recompute the rest.

### Prompt 2.1 — steps read + dashboard card
```
Read mobile/lib/core/health/health_service.dart, lib/features/dashboard/
application/dashboard_controller.dart, domain/daily_stats.dart,
presentation/dashboard_screen.dart, and presentation/widgets/stat_card.dart.

Add today's HealthKit step count to the dashboard as a read-through display
(iOS-only, never persisted or synced):
1. HealthService.todaySteps(): sum HKQuantityType.stepCount for today; return
   int? (null on Android / no permission / unavailable).
2. A Riverpod provider exposing today's steps, auto-refreshing ~every 60s only
   while the app is foregrounded (Timer.periodic gated on AppLifecycleState;
   cancel on pause). Keep this separate from dashboardControllerProvider so its
   refresh doesn't recompute the whole dashboard.
3. A steps StatCard on the dashboard, shown only when steps are non-null so
   Android/denied states hide it cleanly.
Match existing StatCard styling and provider conventions.
```

---

## Phase 3 — Weight sync from Health (30-min dedup)

### Goal
Pull the latest body-weight from Apple Health into the app's weight log, but only
when it's clearly a new measurement — at least 30 minutes apart from the app's
most recent weight entry — to avoid duplicating the same logging event. Old Health
weights are not of interest; only the most recent sample matters.

### Design (mobile only — reuses the existing weight path; no backend change)
- `HealthService.latestBodyMass()` reads the most recent `HKQuantityType.bodyMass`
  sample (value in kg + its timestamp); iOS-only, null otherwise.
- Dedup rule: compare the Health sample's timestamp to the app's latest weight
  entry's timestamp. Import (create a weight entry via the existing
  `WeightRepository.create`, which then syncs normally) only if they differ by
  **≥ 30 minutes**. This prevents re-importing a weight the user just logged in
  the app, and avoids re-adding the same Health sample on repeated checks.
  - Note the existing weight model stores `date` at day granularity plus a local
    `recordedAt`; for a robust 30-min comparison, persist a
    `lastHealthWeightImportedAt` (in settings/prefs) and also compare against the
    latest entry's `recordedAt`. Spell out the exact comparison in the prompt.
- Trigger: on app resume and/or right after permission is granted, behind the
  "Connect Apple Health" toggle. No background polling.

### Prompt 3.1 — weight import with dedup
```
Read mobile/lib/core/health/health_service.dart, lib/features/weight/data/
weight_repository.dart, domain/weight_entry.dart, application/weight_controller.dart,
and where app-resume is already handled (e.g. the connectivity/lifecycle sync
controller in lib/core/sync/).

Add iOS-only weight import from Apple Health:
1. HealthService.latestBodyMass(): most recent HKQuantityType.bodyMass sample as
   (double kg, DateTime timestamp)?; null on Android / no permission.
2. A WeightHealthImporter that, when the "Connect Apple Health" toggle is on,
   reads the latest body mass and creates a weight entry via WeightRepository.create
   ONLY if the sample's timestamp differs from the app's most recent weight
   entry (and from a persisted lastHealthWeightImportedAt) by >= 30 minutes —
   otherwise skip, to avoid duplicating the same measurement. Persist
   lastHealthWeightImportedAt after a successful import. Ignore older samples;
   only the latest matters.
3. Trigger it on app resume / right after permission grant. No background polling.
Reuse the existing offline-first weight create path (it syncs on its own); no
backend changes.
```

---

## 3. Order of work

1. **Phase 0** — foundation + permissions (everything else depends on it).
2. **Phase 1** — backend columns (1.1) → mobile data/sync (1.2) → native observer
   + notification (1.3) → pairing service (1.4) → Apple badge (1.5). The native
   step (1.3) is the riskiest; spike it early to de-risk.
3. **Phase 2** — steps on dashboard (Dart-only, quick win).
4. **Phase 3** — weight import with dedup (Dart-only, reuses weight path).

Phases 2 and 3 are independent of Phase 1 once Phase 0 is in place — if Phase 1's
native work stalls, 2 and 3 can still ship.

## 4. Decisions (confirmed)

- **Phase 1 pairing trigger**: ✅ **manual** — pairing happens only on notification
  tap, via a confirmation dialog the user must accept. Detection never closes or
  modifies a session on its own.
- **Phase 1 no-match case**: ✅ **do nothing** — no standalone imported session
  (we don't want to start writing weights/data we didn't pair).
- **Phase 1 match window**: ✅ **±15 minutes**.
- **Phase 2 steps**: display-only (recommended) — confirm we are NOT syncing steps
  to the backend. *(still open)*
```
