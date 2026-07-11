# Push Notifications — iOS (APNs)

iOS push goes directly through **Apple Push Notification service (APNs)** using
the [Pushy](https://github.com/jchambers/pushy) library with **token-based
(`.p8`) auth** — no per-year certificate renewal.

Implementation: `com.lifey.push` — `ApnsPushSender` (the APNs adapter, only
created when enabled), `PushProperties` (config), `PushService` (fan-out across a
user's devices), `PushDevice`/`PushDeviceController` (token registration).
Design and use cases: [docs/30-push-notifications-plan.md](../docs/30-push-notifications-plan.md).

> **APNs is iOS-only.** Android push is a separate pipe (FCM) —
> see [push-notifications-android.md](push-notifications-android.md).

## Current state / prerequisites

The **backend sender is built and ready.** Before end-to-end push works, three
things still have to be done (tracked as mobile work M1–M3 in the plan):

1. ⚠️ **`aps-environment` entitlement** is **not yet** in `Runner.entitlements`.
   It must be added (`development` for debug builds, Xcode rewrites it to
   `production` for distribution). Adding the **Push Notifications** capability
   in Xcode does this for you.
2. ⚠️ **Push Notifications capability** must be enabled on the App ID
   (`com.khunor.lifey`) in the Apple Developer portal.
3. ⚠️ **Device-token registration** in the Flutter app (platform channel +
   `PUT /api/v1/push/devices`) — not yet implemented. Until it is, no device
   token reaches the backend, so there is nobody to send to.

This doc covers the **APNs credential + backend** side, which is what "configure
Pushy" means. The app-side items above are called out but implemented separately.

## Backend configuration

Bound from `lifey.push.apns.*` (`application.yml`). Set on the **backend** host
(Railway → Variables):

| Variable | Default | Purpose |
|---|---|---|
| `PUSH_APNS_ENABLED` | `false` | Master switch. When `false`, **no APNs bean is created** — the app runs fine and simply has no iOS sender. This is the dev/CI default. |
| `PUSH_APNS_KEY_PATH` | *(empty)* | Filesystem path to the `.p8` signing key. |
| `PUSH_APNS_KEY_ID` | *(empty)* | The key's 10-char Key ID (from the portal / the `.p8` filename). |
| `PUSH_APNS_TEAM_ID` | *(empty)* | Your Apple Developer Team ID (10 chars). |
| `PUSH_APNS_BUNDLE_ID` | `com.khunor.lifey` | APNs topic = the app bundle ID. |
| `PUSH_APNS_SANDBOX` | `true` | `true` = APNs **development** host; `false` = **production** host. See host note. |

### Sandbox vs. production — the part that trips people up

**The same `.p8` key works for both.** What decides which host a token belongs to
is **how the app build was signed**, not the key:

| App build | APNs host | `PUSH_APNS_SANDBOX` |
|---|---|---|
| Run from Xcode to a device (development signing) | development (`api.sandbox.push.apple.com`) | `true` |
| TestFlight or App Store build | production (`api.push.apple.com`) | `false` |

Sending a **sandbox** token to the **production** host (or vice versa) fails with
`BadDeviceToken`. If pushes work in TestFlight but not from an Xcode build (or
vice versa), this flag is almost always why. There is no single value that serves
both at once — match it to the build you're testing.

## First-time setup (getting the `.p8` key)

1. **Apple Developer portal** → Certificates, Identifiers & Profiles → **Keys**
   → **+**.
2. Name it (e.g. "Lifey APNs"), tick **Apple Push Notifications service (APNs)**,
   Continue → Register.
3. **Download `AuthKey_XXXXXXXXXX.p8`.** ⚠️ **This is a one-time download** — Apple
   never lets you download it again. Store it in the password manager / secret
   vault immediately. `XXXXXXXXXX` is the **Key ID**.
4. Note your **Team ID** (top-right of the portal, or Membership page).
5. Ensure the App ID `com.khunor.lifey` has **Push Notifications** enabled
   (Identifiers → your App ID → Capabilities).

### Getting the key onto Railway

The backend reads a **file path** (`PUSH_APNS_KEY_PATH`), so the `.p8` has to
exist in the container's filesystem — but it must **never be committed**.
**Railway has no secret-file / config-file upload** (only Variables and
Volumes), so the file is materialized at startup: store the key **base64-encoded
in a (sealed) Variable** and let the Docker `ENTRYPOINT` decode it to a file.
Full mechanism (encode command + `ENTRYPOINT` snippet, shared with the Firebase
JSON) in
[deploy-backend-railway.md → Secret files](deploy-backend-railway.md#secret-files-apns-p8-firebase-json).

Then set:
```
PUSH_APNS_ENABLED=true
PUSH_APNS_KEY_B64=<base64 of the .p8>   # sealed Variable
PUSH_APNS_KEY_PATH=/tmp/apns.p8
PUSH_APNS_KEY_ID=XXXXXXXXXX
PUSH_APNS_TEAM_ID=YYYYYYYYYY
PUSH_APNS_BUNDLE_ID=com.khunor.lifey
PUSH_APNS_SANDBOX=false        # true while testing an Xcode-built app
```
Redeploy the backend.

## Verification (once app-side registration exists)

APNs cannot be tested on the iOS Simulator — **use a physical device.**

1. Launch the app on a device, log in, accept the notification permission prompt.
2. Confirm a row appeared: the app called `PUT /api/v1/push/devices` — check the
   `push_devices` table (a row for the user with `platform = IOS`).
3. Trigger a send. Easiest real path: create a trainer-scheduled workout for
   today and let `WorkoutReminderJob` fire (or temporarily lower its send hour),
   or add a temporary admin/test endpoint that calls `PushService.sendToUser`.
4. The notification should arrive. Tapping it should deep-link into the app
   (workouts tab) once tap handling (M3) is wired.
5. On failure, check backend logs:
   - `APNs rejected notification to device N: BadDeviceToken` → sandbox/production
     host mismatch (see the table above) or wrong bundle ID.
   - `... : Unregistered` / `ExpiredToken` → the token is dead; the backend
     **auto-soft-deletes** it (`PushSendResult.TOKEN_INVALID`), which is expected
     cleanup, not an error to fix.
   - Startup error initializing the APNs client → bad `.p8` path, Key ID, or Team ID.

## Routine operations

- **Rotating the `.p8` key:** create a new key in the portal, download it, update
  the `PUSH_APNS_KEY_B64` Variable (re-encode) + `PUSH_APNS_KEY_ID`, redeploy,
  then revoke the old key. A
  token-auth key doesn't expire, so rotate only on suspected compromise or team
  changes.
- **Going from TestFlight to App Store:** no key change — both are the production
  APNs host, so `PUSH_APNS_SANDBOX=false` covers both.
- **Invalid-token cleanup is automatic:** APNs `410`/`BadDeviceToken`/`Unregistered`
  responses soft-delete the device row; no manual pruning needed.
- **Turning iOS push off:** set `PUSH_APNS_ENABLED=false` and redeploy — the app
  keeps working, iOS devices just stop receiving.

## App-side capability checklist (for the deploy doc)

When the mobile push work lands, the iOS build must have, in Xcode → Signing &
Capabilities on the **Runner** target:

- **Push Notifications** capability (adds `aps-environment`).
- Background Modes → **Remote notifications** (only if silent/content-available
  pushes are added later; not needed for the current visible reminders).

The existing **App Groups** + **HealthKit** + **Live Activities** capabilities
must stay — see [deploy-ios-appstore.md](deploy-ios-appstore.md) for the full list
so push work doesn't accidentally drop the widget's entitlements.
