# Deploy — iOS to the App Store

Detailed runbook for building and shipping the Flutter iOS app
(`com.khunor.lifey`) to TestFlight and the App Store.

**Read the capability matrix first.** Lifey's iOS build is not a plain Flutter
app — it ships a **widget + Live Activity extension** and uses **HealthKit** and
**App Groups**. These require separate provisioning for **two targets**, and it's
easy to break the widget by re-signing only the main app.

## The two targets (this is the part that trips people up)

| Xcode target | What it is | App ID |
|---|---|---|
| **Runner** | the main app | `com.khunor.lifey` |
| **LifeyWidgets** | app extension: Home-screen widget + Live Activity | `com.khunor.lifey.LifeyWidgets` |

Both must have a registered App ID and a valid provisioning profile. With
automatic signing in Xcode, both get profiles generated for you — but each needs
its capabilities set up on its own App ID (below). If you distribute with only the
main app signed, the widget extension is missing/broken in the build.

## Capability matrix

What each target must have enabled (Xcode → target → Signing & Capabilities), and
where it's already reflected in the repo:

| Capability | Runner | LifeyWidgets | Repo evidence |
|---|---|---|---|
| **App Groups** `group.com.khunor.lifey` | ✅ | ✅ | `Runner.entitlements`, `LifeyWidgets.entitlements` — shared container the widget reads snapshots from |
| App Groups `group.com.khunor.lifey.LifeyWidgets` | ✅ (profile builds) | — | `RunnerProfile.entitlements` |
| **HealthKit** | ✅ | — | `Runner.entitlements` (`com.apple.developer.healthkit`) |
| **Live Activities** | ✅ | ✅ | `Info.plist` → `NSSupportsLiveActivities = true`; the `WorkoutLiveActivity` widget |
| **Push Notifications** | ⚠️ *not yet* | — | to be added when push lands — see [push-notifications-ios.md](push-notifications-ios.md) |

> The App Group is the widget's lifeline: the app writes "today's calories /
> steps / active workout" into the shared container, the widget reads it. If the
> App Group isn't on **both** targets (and registered on the portal), the widget
> shows stale/empty data.

Info.plist also declares the URL schemes the app relies on — the Google Sign-In
reversed-client-ID scheme and the `lifey` deep-link scheme (used by the
widget/Live Activity tap). Don't remove them.

Privacy usage strings already present in `Info.plist` (App Store review checks
these exist and are meaningful — they're currently Hungarian):
- `NSCameraUsageDescription` — barcode scanning + profile photo
- `NSPhotoLibraryUsageDescription` — profile photo picking
- `NSHealthShareUsageDescription` — reading workouts/steps/weight from Apple Health

## Deployment targets & versioning

- **iOS minimum:** the widget/Live Activity extension targets **iOS 16.1**
  (Live Activities require 16.1+); the main app builds against 14.0. Effective
  floor for the widget features is 16.1.
- **Version & build number** come from `mobile/pubspec.yaml` `version:` — currently
  `0.1.0+1`. The part before `+` is `CFBundleShortVersionString` (marketing
  version, e.g. `0.1.0`); after `+` is `CFBundleVersion` (build number, e.g. `1`).
  **Every upload to App Store Connect needs a higher build number.** Bump the
  `+N` for each TestFlight/App Store upload; bump the marketing version for
  user-facing releases.

## Prerequisites

- **Apple Developer Program** membership (paid) with access to the team that owns
  Team ID for `com.khunor.lifey`.
- A **Mac with Xcode** (iOS builds cannot be produced on Windows/Linux — CI here
  builds/analyzes but does not archive iOS).
- **Distribution certificate** (Apple Distribution) in the login keychain — Xcode
  can create it under Settings → Accounts → Manage Certificates.

## First-time portal setup

1. **App IDs** (developer.apple.com → Identifiers): ensure both exist —
   `com.khunor.lifey` and `com.khunor.lifey.LifeyWidgets`.
   - On `com.khunor.lifey` enable: **App Groups**, **HealthKit**, and (when push
     lands) **Push Notifications**.
   - On `com.khunor.lifey.LifeyWidgets` enable: **App Groups**.
2. **App Group** (Identifiers → App Groups): register `group.com.khunor.lifey`
   and assign it to **both** App IDs. (Also `group.com.khunor.lifey.LifeyWidgets`
   if your profile builds use it.)
3. **App Store Connect** (appstoreconnect.apple.com → Apps → +): create the app
   record for `com.khunor.lifey` if it doesn't exist (name, primary language,
   bundle ID, SKU).

## Build & upload

From `mobile/`:

1. **Clean & fetch:**
   ```bash
   flutter clean
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   ```
2. **Confirm signing in Xcode** (`open ios/Runner.xcworkspace`): both **Runner**
   and **LifeyWidgets** targets → Signing & Capabilities → correct Team, automatic
   signing, no red capability errors.
3. **Build the release archive:**
   ```bash
   flutter build ipa --release
   ```
   This produces `build/ios/archive/Runner.xcarchive` and an `.ipa` under
   `build/ios/ipa/`.
4. **Upload** the `.ipa` via **Transporter** (Mac App Store app) or Xcode →
   Organizer → Distribute App. Or `xcrun altool`/`notarytool` if scripted.
5. The build appears in **App Store Connect → TestFlight** after processing
   (several minutes).

## App Store Connect: review essentials

- **Export compliance:** the app uses only standard HTTPS encryption → typically
  "exempt". Answer the encryption question on each build (or set
  `ITSAppUsesNonExemptEncryption=false` in Info.plist to stop being asked).
- **App Privacy** (Data Safety equivalent): declare **Health & Fitness** data
  (read from HealthKit, used on-device), and any account/contact data. Be
  accurate — health data gets extra scrutiny.
- **HealthKit review note:** Apple often asks how HealthKit data is used. Have a
  one-liner ready ("reads workouts, steps, and weight to auto-fill the user's
  log; no health data leaves the device except the user's own synced entries").
- **Screenshots** for the required device sizes, description, keywords, support
  URL, privacy policy URL.

## TestFlight → release

1. In TestFlight, add the build to a test group; install on a real device.
2. **Smoke test on-device** (Simulator can't do HealthKit or real push):
   - login, log a meal/workout/weight;
   - Apple Health import;
   - add the **Home-screen widget** → shows today's calories/steps;
   - start a workout → **Live Activity** appears (Dynamic Island / lock screen);
   - (once push lands) notification permission + a test push.
3. When happy, App Store → create a new version → attach the build → submit for
   review.

## Widget-specific gotchas

- **Widget shows no data:** App Group missing on a target or not registered on the
  portal, or the app hasn't written a snapshot yet. Verify the App Group is on
  **both** App IDs and both entitlements files.
- **Live Activity never appears:** `NSSupportsLiveActivities` must be `true`
  (it is, in `Info.plist`), and the device must be iOS 16.1+.
- **Widget missing from the build entirely:** the LifeyWidgets target wasn't
  signed/embedded — check its provisioning profile in Xcode.
- **Re-signing for a new team:** update the Team on **both** targets and
  re-register the App Group + App IDs under the new team, or the widget breaks
  while the main app still installs.

## Related

- Push (APNs) capability + backend: [push-notifications-ios.md](push-notifications-ios.md).
- Backend the app talks to: [deploy-backend-railway.md](deploy-backend-railway.md).
