# Deploy — Android to Google Play

Detailed runbook for building and shipping the Flutter Android app
(`com.khunor.lifey`) to Google Play.

Like iOS, this isn't a plain Flutter app — it uses **Health Connect** (sensitive
permissions that trigger extra Play review) and ships a **Home-screen widget**.
And there's one thing that **must** be fixed before a real release: the app
currently signs its release build with **debug keys**.

## ⚠️ Blocker before any Play release: release signing

`mobile/android/app/build.gradle.kts` currently has:

```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

Debug-signed builds **cannot** go to Google Play. You must create an **upload
keystore** and wire a real release signing config first.

1. **Generate an upload keystore** (once, keep it forever — losing it means you
   can't update the app without a Play key reset):
   ```bash
   keytool -genkey -v -keystore lifey-upload.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias upload
   ```
   Store `lifey-upload.jks` in the vault. ⚠️ **Never commit it.**
2. **Create `mobile/android/key.properties`** (git-ignored) referencing it:
   ```properties
   storeFile=/absolute/path/to/lifey-upload.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```
3. **Wire it into `build.gradle.kts`** — load `key.properties`, define a
   `signingConfigs { create("release") { ... } }`, and point
   `buildTypes.release.signingConfig` at it. Standard Flutter release-signing
   setup (see flutter.dev → "Build and release an Android app").
4. Add `key.properties` and `*.jks` to `.gitignore` if not already covered.

**Use Play App Signing** (default for new apps): you upload with the *upload* key,
Google re-signs with the *app* key it holds. This is the recommended path and
makes upload-key loss recoverable.

## Build config facts

| Setting | Value | Source |
|---|---|---|
| applicationId | `com.khunor.lifey` | `build.gradle.kts` |
| minSdk | **26** | required by the `health` / Health Connect plugin |
| compileSdk | **36** | Health Connect needs API 35+; set via `gradle.properties` |
| targetSdk | Flutter default | `flutter.targetSdkVersion` |
| versionCode / versionName | from `pubspec.yaml` `version:` (`0.1.0+1` → name `0.1.0`, code `1`) | Flutter |

**Every Play upload needs a higher `versionCode`** — bump the `+N` in
`pubspec.yaml` (`0.1.0+2`, `0.1.0+3`, …) for each release.

## Permissions that affect Play review

Declared in `mobile/android/app/src/main/AndroidManifest.xml`:

- **Health Connect** (`android.permission.health.READ_*` for steps, weight, heart
  rate, exercise, active calories, + `ACTIVITY_RECOGNITION`). These are
  **sensitive** — Google Play requires:
  - a **Data Safety** form declaration for health data, and
  - a **Health Connect declaration** (Play Console → App content) justifying each
    health data type, often with a demo video.
  - The manifest already includes the `ViewPermissionUsageActivity` alias and the
    `ACTION_SHOW_PERMISSIONS_RATIONALE` intent filter that Play requires for
    sensitive health permissions — don't remove them.
- **`POST_NOTIFICATIONS`** (Android 13+) — for step-goal / workout / reminder
  notifications. Requested at runtime.
- **`CAMERA`** — barcode scanning.
- **`INTERNET`** — backend access.

Budget review time: health-permission apps are reviewed more slowly and may bounce
if the declaration/demo doesn't clearly show each data type in use.

## The Home-screen widget

`TodaySummaryWidgetProvider` (an `AppWidgetProvider` receiver) is declared in the
manifest — no extra Play configuration is needed, it ships inside the APK/AAB.
Just verify it works post-install (below).

## Build the release bundle

Google Play requires an **Android App Bundle (`.aab`)**, not an APK.

From `mobile/` (after the signing config above is in place):
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`.

(For local install testing you can also `flutter build apk --release` and
sideload, but Play only accepts the `.aab`.)

## Play Console: first submission

1. **Create the app** (Play Console → Create app): name, default language,
   app/game, free/paid.
2. **Complete the required declarations** (App content): privacy policy, Data
   Safety (incl. **health data**), ads, content rating, target audience,
   **Health Connect** declaration.
3. **Set up Play App Signing** (accepted during the first upload — let Google
   generate/hold the app signing key; you keep the upload key).
4. **Create a release** on an appropriate track:
   - **Internal testing** (fastest, up to 100 testers — use this first),
   - then **Closed/Open testing**, then **Production**.
5. **Upload `app-release.aab`**, add release notes, review, roll out.

## Verification (on a real device / emulator with Play services)

1. Install the internal-testing build.
2. Login; log a meal/workout/weight.
3. **Health Connect**: connect and confirm steps/weight import (requires Health
   Connect installed; on Android 14+ it's part of the OS).
4. Grant the **notifications** permission; confirm a local notification fires
   (e.g. step goal).
5. Add the **Home-screen widget** → shows today's calories.
6. (Once Android push lands) confirm an FCM push arrives — see
   [push-notifications-android.md](push-notifications-android.md).

## Troubleshooting

- **"App Bundle signed with the wrong key" / upload rejected:** the release build
  is still debug-signed, or the upload key doesn't match what Play expects. Redo
  the signing config; confirm Play App Signing is set up.
- **Health permissions rejected in review:** the Health Connect declaration or
  Data Safety form is incomplete — every requested `READ_*` type must be
  justified, and the demo must show it in use.
- **`minSdk`/build errors after a plugin bump:** the Health Connect plugin pins
  minSdk 26 / compileSdk 35+ — don't lower them.
- **Widget not updating:** it updates on the `APPWIDGET_UPDATE` schedule and when
  the app writes new data; confirm the app ran at least once after install.

## Related

- Android push (FCM) — still to be integrated app-side:
  [push-notifications-android.md](push-notifications-android.md).
- Backend the app talks to: [deploy-backend-railway.md](deploy-backend-railway.md).
