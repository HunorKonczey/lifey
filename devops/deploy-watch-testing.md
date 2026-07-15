# Deploy — watchOS & Wear OS, test/dev install

Runbook for getting the **Apple Watch** and **Wear OS** companion apps
(docs/40-watch-app-plan.md) onto a real watch for development testing — **no
paid Apple Developer Program membership required** for this. This doc is scoped
to *test/dev* install; TestFlight/Play Store distribution needs the same
prerequisites as the phone app (see [deploy-ios-appstore.md](deploy-ios-appstore.md)
and [deploy-android-playstore.md](deploy-android-playstore.md)) plus a paid
Apple account for the watch side.

## Current state

Native watch targets don't exist yet — this doc covers **F0 (spike) and F2/F3
(native watch app) setup** from docs/40-watch-app-plan.md. The Dart-side bridge
(`WatchWorkoutService`, `mobile/lib/core/watch/watch_workout_service.dart`) is
already in the repo and safely no-ops (catches `MissingPluginException`) until
the native targets below are added — so nothing here blocks the phone app from
building/running as-is.

## Apple Watch — what works without a paid account

| Capability | Free Apple ID ("Personal Team") | Paid Apple Developer Program |
|---|---|---|
| watchOS Simulator | ✅ full — no account at all needed | ✅ |
| Install on your own physical iPhone + paired Watch, via Xcode | ✅ | ✅ |
| HealthKit (read + write, incl. `HKWorkoutSession`) | ✅ — HealthKit is a free capability | ✅ |
| App lifetime on-device | **7 days**, then re-install from Xcode | 1 year (dev) / indefinite (release) |
| Concurrent free-account apps on one device | max **3** (App Groups/extensions each count) | no such cap |
| App IDs created per week | **10** | no such cap |
| TestFlight (handing the build to someone else) | ❌ | ✅ |
| App Store release | ❌ | ✅ |

**Bottom line:** the entire F0 spike and F2 iOS watch MVP (docs/40-watch-app-plan.md
§4) can be built and tested end-to-end, on a real Watch, with a free Apple ID. The
paid membership only becomes necessary when this ships to TestFlight or the
App Store.

### Free-account App ID budget for this project

Lifey already uses 2 App IDs (`com.khunor.lifey`, `com.khunor.lifey.LifeyWidgets`
— see [deploy-ios-appstore.md](deploy-ios-appstore.md)). Adding a watch target
costs at least 1 more:

| App ID | Target | Already exists? |
|---|---|---|
| `com.khunor.lifey` | Runner (phone) | ✅ |
| `com.khunor.lifey.LifeyWidgets` | Home-screen widget + Live Activity | ✅ |
| `com.khunor.lifey.watchkitapp` | `LifeyWatch` (new, this doc) | ❌ — created on first build |

That's 3 App IDs on a free account, at the free-tier cap — a 4th (e.g. a watch
widget/complication extension) won't fit until upgrading to a paid membership.

### First-time setup (Mac + Xcode required — iOS builds don't run on Windows/Linux)

1. **Sign in with your Apple ID** in Xcode: Xcode → Settings → Accounts → **+** →
   Apple ID. No payment or enrollment needed for this step.
2. **Enable Developer Mode on both devices** (required since iOS 16 / watchOS 9,
   separate from “Developer options” on Android):
   - iPhone: Settings → Privacy & Security → **Developer Mode** → on → restart.
   - Watch: Settings app on the Watch → Privacy & Security → **Developer Mode** →
     on → the Watch restarts.
3. **Add the watch target** in `mobile/ios/Runner.xcworkspace` (File → New →
   Target → watchOS → **App**, "LifeyWatch", embed in Runner, SwiftUI interface,
   include a Watch App only — no Notification/Complication targets yet). This
   registers `com.khunor.lifey.watchkitapp` the first time you build.
4. **Signing** on the new `LifeyWatch` target (and its `LifeyWatch WatchKit
   Extension` sub-target, if Xcode splits them): Signing & Capabilities → check
   **Automatically manage signing** → select your **Personal Team** (shows as
   "Your Name (Personal Team)").
5. **HealthKit capability** on `LifeyWatch`: Signing & Capabilities → **+
   Capability** → HealthKit. Add `NSHealthShareUsageDescription` and
   `NSHealthUpdateUsageDescription` to the watch target's `Info.plist` (the
   watch **writes** the finished workout, so it needs the update string too,
   unlike a read-only extension).
6. **Background mode**: Signing & Capabilities → **+ Capability** → Background
   Modes → check **Workout processing** (without this, the session dies when
   the wrist lowers / the app backgrounds).
7. **Build to device**: select the paired **Watch** as the run destination (or
   select the iPhone — Xcode auto-installs the paired watch app alongside it),
   ▶ Run. First install over the air to the Watch is slow (several minutes) —
   this is normal, not a free-account penalty.
8. **Trust the developer certificate** if prompted: iPhone → Settings → General
   → VPN & Device Management → your Apple ID → Trust.
9. **Grant HealthKit permission** — the *first* `startWatchApp` call (or first
   manual open of `LifeyWatch`) prompts on the **Watch's own screen**, not the
   phone. Small screen, easy to miss — check the Watch face if nothing seems to
   happen after a start-workout call.

### The 7-day expiry, in practice

A free-account build stops launching 7 days after install (`Xcode` shows
"Verifying" errors if you try to reopen an expired app). For active development
this just means: re-run from Xcode whenever you sit down to test after a gap.
No data loss — HealthKit data already written persists regardless.

### Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| "Maximum number of apps for free development profiles reached" | Free account's 3-app cap hit | Remove/re-sign an unrelated dev app on the device, or upgrade to paid |
| Watch app never launches after `startWatchApp` | Developer Mode off on the Watch, or the paired Watch app was never installed once from Xcode | Enable Developer Mode (step 2); do one manual Xcode install first |
| HealthKit permission dialog never appears | It renders on the **Watch**, not the phone | Check the Watch screen directly after the triggering call |
| "App installation failed" after 7 days | Free-profile expiry | Re-build/run from Xcode — no account action needed |
| Build error: "no profiles for 'com.khunor.lifey.watchkitapp' were found" | New App ID hasn't been created yet, or automatic signing is off | Toggle **Automatically manage signing** off then on to force Xcode to (re)register it |

## Wear OS — what works without a Play Console account

Android has no paid-account gate at all for sideloaded testing — this section
exists mainly to flag the two things people expect to need and don't.

| Capability | Requirement |
|---|---|
| Build & install the wear module via `adb`/Android Studio | Free — no Google account needed on the *dev machine* |
| `BODY_SENSORS` runtime permission | Granted on-device like any Android runtime permission — no account |
| Health Services / `ExerciseClient` | No account, no entitlement — it's a public Jetpack API |
| Health Connect writes | No account |
| Play Console (only for a *Play Store* release, not sideloading) | Paid, one-time $25 registration — **not needed for this doc** |

### First-time setup

1. **Add the wear module**: `mobile/android/wear/` as a new Gradle module (see
   docs/40-watch-app-plan.md §5.1), added to `mobile/android/settings.gradle`.
   Use the **same `applicationId`** as the phone app (`com.khunor.lifey`) — the
   Wearable Data Layer (`MessageClient`/`DataClient`) requires matching IDs to
   talk to each other, and a mismatched signature blocks it too, so debug-sign
   both with the same debug keystore during development.
2. **Pick a test target** — either works, no account needed for either:
   - **Physical Wear OS watch**: Settings on the watch → System → About →
     tap Build number ×7 (Developer options) → enable **ADB debugging** and
     **Debug over Wi-Fi** (Wear OS watches rarely have a USB port) →
     `adb connect <watch-ip>:5555`.
   - **Wear OS emulator** (Android Studio → Device Manager → create a Wear OS
     device, e.g. "Wear OS Large Round" API 33+) — simplest for early
     iteration; can inject synthetic sensor data via the emulator's Extended
     Controls → **Health Services**.
3. **Pair the emulator/watch with a phone (real or emulator)**: the **Wear OS
   app** (on the phone) pairs them — required for the Data Layer to route
   messages, even between two emulators. Two Android emulators can be paired
   via the Wear OS companion app the same as a real phone+watch.
4. **Install both APKs**: `flutter build apk` (or run) for the phone module,
   `./gradlew :wear:installDebug` for the wear module, from `mobile/android/`.
5. **Manifest capability check**: confirm `wear/src/main/AndroidManifest.xml`
   declares the `<uses-feature android:name="android.hardware.type.watch"/>`
   and the phone-side `WatchBridge` can see the watch via `CapabilityClient`
   before assuming a missing-watch bug is actually a pairing bug.

### Synthetic sensor data for testing

The Wear OS emulator's **Extended Controls → Health Services** panel lets you
inject a fake heart rate and step/calorie stream while an `ExerciseClient`
session is active — use this to test the strength-workout HR/kcal display
without needing to physically wear the device and move.

### Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Phone never sees the watch (`CapabilityClient` returns empty) | Different `applicationId` or debug signature on phone vs. wear build, or they were never paired via the Wear OS app | Confirm both `applicationId`s match; re-pair via the Wear OS companion app |
| `startExercise` immediately fails | Another app (e.g. Wear OS's own Fitbit/Fit app) already owns an active exercise on the watch | Stop the other app's workout first — Health Services allows only one exercise owner at a time (docs/40-watch-app-plan.md §5.3) |
| No heart rate on a physical watch | `BODY_SENSORS` permission denied | Re-prompt from the watch app; check Settings → Apps → LifeyWatch (Wear OS) → Permissions on the watch |
| `adb connect` to the watch times out | Watch and dev machine not on the same Wi-Fi, or Debug over Wi-Fi toggled off after a watch reboot | Re-enable Debug over Wi-Fi in Developer options after every watch restart — it doesn't persist |

## Related

- Feature plan and architecture: [docs/40-watch-app-plan.md](../docs/40-watch-app-plan.md)
- iOS phone-app signing/capabilities baseline: [deploy-ios-appstore.md](deploy-ios-appstore.md)
- Android phone-app signing/capabilities baseline: [deploy-android-playstore.md](deploy-android-playstore.md)
