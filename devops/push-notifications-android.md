# Push Notifications — Android (FCM)

Android push goes through **Firebase Cloud Messaging (FCM)** using the
**Firebase Admin SDK** with **service-account (JSON key)** auth.

Implementation: `com.lifey.push` — `FcmPushSender` (the FCM adapter, only created
when enabled), `FcmConfig` (`FirebaseApp`/`FirebaseMessaging` beans),
`FcmProperties` (config). It plugs into the same `PushService` / `PushDevice`
machinery as iOS — the service fans a message out to all of a user's devices and
picks the sender per platform, so no `PushService` change was needed to add
Android.

> **FCM here is Android-only.** iOS uses APNs directly —
> see [push-notifications-ios.md](push-notifications-ios.md). (FCM *can* proxy to
> APNs, but Lifey talks to APNs directly, so FCM carries Android only.)

## Current state / prerequisites

The **backend sender is built and ready.** End-to-end Android push additionally
needs (mobile-side work, not yet built):

1. ⚠️ A **Firebase project** with an Android app registered for `com.khunor.lifey`,
   and its **`google-services.json`** placed in `mobile/android/app/`.
2. ⚠️ The **Google Services Gradle plugin** + `firebase_messaging` Flutter package
   wired into the Android app (token retrieval → `PUT /api/v1/push/devices` with
   `platform: "ANDROID"`). Not yet integrated.
3. ⚠️ The backend **service-account JSON key** (below).

This doc covers the **Firebase credential + backend** side.

## Backend configuration

Bound from `lifey.push.fcm.*` (`application.yml`). Set on the **backend** host:

| Variable | Default | Purpose |
|---|---|---|
| `PUSH_FCM_ENABLED` | `false` | Master switch. When `false`, **no Firebase beans are created** — the app runs fine with no Android sender. Dev/CI default. |
| `PUSH_FCM_CREDENTIALS_PATH` | *(empty)* | Filesystem path to the Firebase **service-account** JSON key. |

There is no host/sandbox flag for FCM (unlike APNs) — one credential covers debug
and release Android builds within the same Firebase project.

## First-time setup

### 1. Firebase project + Android app

1. <https://console.firebase.google.com> → create a project (or reuse one).
2. Add an **Android app**, package name **`com.khunor.lifey`**.
3. Download the generated **`google-services.json`** → place at
   `mobile/android/app/google-services.json`. ⚠️ Do **not** commit it — add to
   `.gitignore` if it isn't matched already. (It's not a high-value secret, but
   keeping build config out of git is the convention here.)

### 2. Service-account key (backend)

1. Firebase console → **Project settings** (gear) → **Service accounts**.
2. **Generate new private key** → downloads a JSON file. ⚠️ **Treat as a secret**
   — it can send push on your behalf and access other project resources. Store in
   the vault; never commit.
3. Get it onto Railway the same way as the APNs key. **Railway has no file-mount**
   — store the JSON **base64-encoded in a (sealed) Variable** and let the Docker
   `ENTRYPOINT` decode it to a file on startup. Full mechanism (encode command +
   `ENTRYPOINT` snippet) in
   [deploy-backend-railway.md → Secret files](deploy-backend-railway.md#secret-files-apns-p8-firebase-json).
4. Set on the backend service:
   ```
   PUSH_FCM_ENABLED=true
   PUSH_FCM_CREDENTIALS_B64=<base64 of firebase.json>   # sealed Variable
   PUSH_FCM_CREDENTIALS_PATH=/tmp/firebase.json
   ```
   Redeploy the backend.

## Verification (once app-side registration exists)

Unlike APNs, FCM **works on an emulator** (with Google Play services), so a
physical device isn't strictly required.

1. Launch the app on an Android device/emulator, log in, grant the Android 13+
   `POST_NOTIFICATIONS` permission.
2. Confirm a `push_devices` row exists for the user with `platform = ANDROID`.
3. Trigger a send (same options as iOS — `WorkoutReminderJob`, or a temporary
   test call to `PushService.sendToUser`).
4. On failure, check backend logs:
   - `FCM rejected notification to device N: UNREGISTERED` → dead token; the
     backend **auto-soft-deletes** it — expected cleanup.
   - `FCM rejected notification to device N: INVALID_ARGUMENT` → malformed token
     or message; usually a wrong/short token from the app side.
   - `FCM rejected notification to device N: SENDER_ID_MISMATCH` → the
     `google-services.json` in the app and the service-account key on the backend
     belong to **different Firebase projects**. They must match.
   - Startup failure → bad credentials path or malformed service-account JSON.

## Routine operations

- **Rotating the service-account key:** Firebase → Service accounts → generate a
  new key, update the `PUSH_FCM_CREDENTIALS_B64` Variable (re-encode), redeploy,
  then delete the old key in the Google Cloud IAM console (Service Accounts →
  Keys).
- **Invalid-token cleanup is automatic:** FCM `UNREGISTERED` soft-deletes the
  device row.
- **Turning Android push off:** set `PUSH_FCM_ENABLED=false` and redeploy.
- **Keep projects aligned:** the app's `google-services.json` and the backend's
  service-account key must always be from the **same** Firebase project, or every
  send fails with `SENDER_ID_MISMATCH`.

## App-side checklist (for the deploy doc)

When Android push work lands, the Android build needs:

- `google-services.json` in `mobile/android/app/`.
- The Google Services Gradle plugin applied (`mobile/android/build.gradle.kts`
  classpath + `mobile/android/app/build.gradle.kts` plugin), plus the
  `firebase_messaging` package in `pubspec.yaml`.
- `POST_NOTIFICATIONS` is **already** declared in the manifest (used today by the
  local step-goal / workout-session notifications), so no manifest change is
  needed for the permission itself.
