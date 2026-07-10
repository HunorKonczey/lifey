# 26 – Android Health Connect integration

Status: implemented
Android counterpart of [16-apple-health-integration-plan.md](16-apple-health-integration-plan.md),
which is iOS-only. Every feature that doc built on top of Apple HealthKit —
permission foundation, manual workout import (calories + avg HR), dashboard
step count, weight sync — is now available on Android too via Google Health
Connect, using the same `HealthService` API.

## Why this wasn't a parallel implementation

The `health` pub package (already a dependency for the iOS work, v13.3.1) is
a **unified** wrapper over both HealthKit and Health Connect: the exact same
`HealthDataType`/`getHealthDataFromTypes`/`requestAuthorization` calls
`HealthService` already used for iOS work unchanged on Android. So this was
removing the `Platform.isIOS` restriction and adding Android-side native
setup (manifest permissions, Health Connect install/availability handling),
not writing a second read path.

## What's platform-specific

### Health Connect isn't guaranteed installed

Unlike HealthKit (built into iOS), Health Connect is a separate app on
Android < 14 (built-in from API 34, this project's emulator — API 37 —
already has it). Every `health` plugin call
(`requestAuthorization`/`getHealthDataFromTypes`/...) internally checks this
and **throws `UnsupportedError`** if it isn't installed.
`HealthService._guarded<T>` wraps every read method to catch this (and any
other platform-channel failure) and return the same "no data" fallback
(`null`/`[]`/`{}`) the "no permission" case already returns — callers don't
need to know or care why data is missing.

For the opt-in toggle specifically (where "not installed" needs a different
UX than "no data"), `HealthService.isHealthConnectInstalled()` /
`promptInstallHealthConnect()` let `HealthController.setEnabled(true)` check
first and open the Play Store instead of requesting permissions against a
store that isn't there.

### Manifest wiring (`mobile/android/app/src/main/AndroidManifest.xml`)

Confirmed against the `health` package's own example app manifest, not
guessed:

- One `android.permission.health.READ_*` per `HealthDataType` this app
  reads: `READ_STEPS`, `READ_WEIGHT`, `READ_HEART_RATE`, `READ_EXERCISE`
  (this is the permission name for `HealthDataType.WORKOUT`, not
  `READ_WORKOUT`), `READ_ACTIVE_CALORIES_BURNED`. Plus
  `android.permission.ACTIVITY_RECOGNITION`, Health Connect's own
  prerequisite for step data. Read-only — no `WRITE_*` permissions, this app
  never writes to Health Connect.
- `<queries>` additions: the `com.google.android.apps.healthdata` package
  (so the app can detect whether it's installed) and the
  `androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE` intent.
- An `ACTION_SHOW_PERMISSIONS_RATIONALE` intent-filter on `.MainActivity`
  and a `ViewPermissionUsageActivity` activity-alias targeting it — Health
  Connect's own permissions screen links back to the app through these.

### `MainActivity.kt`

`FlutterActivity` → `FlutterFragmentActivity`. The plugin's Android 14+
permission flow uses `registerForActivityResult`, which needs a
`ComponentActivity` — `FlutterFragmentActivity` provides that,
`FlutterActivity` doesn't.

### Workout activity type mapping

HealthKit distinguishes `TRADITIONAL_STRENGTH_TRAINING` and
`FUNCTIONAL_STRENGTH_TRAINING`; Health Connect has one `STRENGTH_TRAINING`
type that both collapse into when read back on Android (confirmed from the
`health` package's own workout-type mapping table). `HealthService`'s
`_strengthActivityTypes` filter lists all three, so the Phase 1 import
matches on both platforms without the caller needing to know which one it's
running on.

### Gradle

No manual dependency needed — the `health` plugin's own `android/build.gradle`
declares `minSdkVersion 26` (already this project's `minSdk`) and bundles
`androidx.health.connect:connect-client` transitively.

## Rename pass

Once `HealthService.isAvailable` is true on Android, every "Apple Health"
label became factually wrong there. Renamed (mobile Dart + l10n only — same
precedent as the `WorkoutLiveActivityService` →
`WorkoutSessionNotifierService` rename in the widget/notification work):

- `AppleHealthController`/`appleHealthControllerProvider` → `HealthController`/
  `healthControllerProvider`; `_AppleHealthRow`/`_AppleHealthSwitch` →
  `_HealthRow`/`_HealthSwitch`; `AppleWorkout` → `HealthWorkout`
  (`apple_workout.dart` → `health_workout.dart`,
  `apple_workout_picker_sheet.dart` → `health_workout_picker_sheet.dart`);
  the onboarding wizard's `_AppleHealthStep` → `_HealthStep`.
- Every l10n key with "apple" in the name (`appleHealthLabel`,
  `importFromAppleHealthButton`, `pairAppleWorkoutTitle/Message`,
  `noAppleWorkoutTitle/Message`, `noRecentAppleWorkoutMessage`,
  `pickAppleWorkoutTitle`, `importedFromAppleHealthTooltip`,
  `appleHealthStatsLine`) renamed to generic equivalents, text reworded
  "Apple Health" → "Health" (EN) / "Egészségügyi adatok" (HU). Two dead keys
  (`connectAppleHealthLabel`/`connectAppleHealthDescription`, unused
  anywhere in `lib/`) were deleted rather than renamed.
- `Icons.apple` (weight-screen import button, sessions-tab imported badge) →
  `Icons.favorite` — already the icon used for the settings health row, so
  the "health" concept reads consistently instead of platform-branching the
  icon.
- **Not renamed**: backend Java entity/DTO fields and the Drift/domain
  `activeCalories`/`averageHeartRate`/`healthWorkoutId`/`fromAppleHealth`
  names. Internal sync-path identifiers, not user-facing — renaming them
  would touch backend columns/DTOs/Flyway for zero functional gain.

## Onboarding wizard gap (caught mid-implementation)

The initial platform-gate audit searched `lib/core/health`,
`lib/features/{dashboard,workouts,settings,weight}` and found exactly 3
`Platform.isIOS` gates. It missed `lib/features/onboarding/presentation/onboarding_screen.dart`,
which had **3 more**: `_stepCount` (6 steps on iOS, 5 elsewhere), the
post-goals-step branch that decides whether to advance to the Health step or
go straight to the dashboard, and the step list itself gating
`_AppleHealthStep`. All three now check `Platform.isIOS || Platform.isAndroid`.
Lesson for next time: grep the whole `lib/` tree for `Platform.isIOS`, not
just the directories that seem obviously related.

## Testing

No new automated tests — `HealthService`'s guarded-read fallback shape
(`null`/`[]`/`{}}`) is unchanged from before, so existing call sites and
their tests keep working unmodified. Verified via `flutter analyze` (clean),
`flutter test` (full suite, 93 tests passing), and `flutter build apk --debug`
installed on the emulator with manifest permissions confirmed via
`adb shell dumpsys package`.

Manual on-device verification (Health Connect permission screen actually
opening, workout import round-tripping, step count/weight sync working
end-to-end) was not performed in this session — the emulator's Health
Connect app was not exercised interactively beyond confirming the manifest
permissions are declared. This is the one gap between "compiles and analyzes
clean" and "confirmed working," same caveat noted in doc 25 for its own
manual QA checklist.
