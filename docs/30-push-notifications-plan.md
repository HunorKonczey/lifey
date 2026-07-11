# Push Notifications Plan (Roadmap #8)

Goal: stand up real (remote) push infrastructure end-to-end — device token
registration, cross-platform backend senders (APNs + FCM), and one
server-triggered use case — plus one purely local reminder. Four
deliverables:

1. **Backend push infrastructure** — APNs for iOS and FCM for Android, both
   behind one `PushSender` interface. **Both senders are now implemented**
   (APNs via Pushy, Android via the Firebase Admin SDK); see the design
   decision below and [devops/push-notifications-ios.md](../devops/push-notifications-ios.md)
   / [devops/push-notifications-android.md](../devops/push-notifications-android.md)
   for the credential/ops side.
2. **Trainer-scheduled workout reminder** (remote push) — on the morning of
   a scheduled occurrence, the client gets "You have a workout today".
3. **Morning weigh-in reminder** (local, opt-in) — a daily local
   notification at a user-chosen time; no backend involvement.
4. **Notification settings screen** — a "Notifications" entry on the
   settings screen opening a dedicated page where every notification type
   has its own switch, plus a master switch to flip them all at once. The
   existing step-goal notification gets a toggle here too.

Roadmap framing: the infrastructure is the point — #13 (trainer comment
push) and future notifications build on it. The two use cases here are
deliberately small proofs that the pipe works in both directions
(server-triggered and device-scheduled).

## Current state

Mobile:

* `NotificationService` (`lib/core/notifications/notification_service.dart`)
  wraps `flutter_local_notifications` — local only. Channels: step goal,
  ongoing workout session (Android). iOS Darwin init already requests alert
  + sound permission on first fire; Android 13+ `POST_NOTIFICATIONS` is
  requested lazily per channel via `_ensureAndroidChannel`.
* Baseline (before this plan): no `firebase_messaging`, no APNs
  registration, no push entitlement. **Status now:** iOS M1 is done —
  `aps-environment` added to `Runner.entitlements`/`RunnerProfile.entitlements`
  and a `lifey/push` platform channel (`PushChannel.swift`) registers the
  APNs token. Android M1b is also done — `firebase_messaging`/`firebase_core`
  wired in, `google-services` Gradle plugin conditionally applied,
  `AndroidPushTokenSource` implemented. M2 (shared registrar, wired into
  `AuthController`), M3 (tap handling/deep link, both platforms), M4
  (local weigh-in reminder mechanism), and M5 (notification settings
  screen) are also done. **M1–M5 are fully implemented** — only M6
  (the manual on-device verification pass) remains.
* Native iOS work is established practice (widgets, Live Activity), so the
  `PushChannel` in `AppDelegate` is in line with the codebase.

Backend:

* No push/notification feature package. Mail is the closest analog:
  `MailProperties` (`@ConfigurationProperties`), `MailService`/
  `ResendMailService`, `MailLanguageResolver` (user language via
  `UserSettings`, default EN) — the same shapes apply here.
* `@EnableScheduling` is on; two cron jobs exist
  (`PasswordResetTokenCleanupJob`, `TrainerClientCleanupJob`) — the
  reminder job follows that pattern.
* `users.utc_offset_minutes` (V46) is kept fresh on every auth flow by
  `UserUtcOffsetUpdater` — this is how "morning, user-local time" is
  computed server-side without a timezone table.
* Trainer-scheduled occurrences are `WorkoutSession` rows with
  `scheduledFor` (`LocalDate`), `scheduledTime` (`LocalTime`, nullable),
  `startedAt == null` until begun, soft-deleted on cancel. Latest
  migration: V51.

## Design decisions

**APNs for iOS, FCM for Android — one `PushSender` seam.** The roadmap said
"APNs, later FCM". iOS talks to APNs **directly** (not proxied through FCM)
via the [Pushy](https://github.com/jchambers/pushy) Java library
(`com.eatthepath:pushy`, token-based `.p8` auth, no cert renewal); Android
goes through **FCM** via the Firebase Admin SDK (`com.google.firebase:firebase-admin`,
service-account JSON auth). Both are just plain libraries, not frameworks
(justification per the "no new frameworks" rule: there is no push without a
provider client).

The `PushSender` interface is keyed on device platform, so `PushService`
fans a message out to a user's devices and picks the right sender per
device with **no per-platform branching in the caller** — adding the second
sender needed one new impl + config, no schema or API change. Both senders
are `@ConditionalOnProperty`-gated (`push.apns.enabled` / `push.fcm.enabled`),
so local dev and CI run with neither configured, and either platform can be
switched off independently in production.

**Device tokens are their own feature package** (`com.lifey.push/`), not
part of `auth` or `settings`: it will grow (FCM, notification log,
per-type preferences) and is reached by other features (trainer job).

**One reminder per occurrence, marked on the row.** A
`reminder_sent_at` column on `workout_sessions` is simpler and more
debuggable than a separate send-log table, and the "has this been
reminded" check is exactly a per-occurrence fact.

**The weigh-in reminder never touches the backend.** It's a repeating
local notification scheduled on-device; the opt-in toggle + time live in
local storage.

**Preferences live where they are enforced.** The workout reminder is
sent by the server, so its toggle is a `UserSettings` column the job
checks (synced through the existing `/settings` API). The weigh-in and
step-goal notifications are produced on-device, so their toggles stay in
local prefs. The notification settings screen presents all three
uniformly; where each value is stored is an implementation detail the
user never sees. A generic server-side preference center (per-type rows,
quiet hours, channels) stays out of scope until there are more remote
types.

## Backend plan

### B1 — `push` feature package + device registration

New package `com.lifey.push/`:

* `PushDevice` entity (extends `BaseEntity`): `user` (ManyToOne),
  `platform` (enum `PushPlatform { IOS, ANDROID }`), `token` (unique),
  `lastRegisteredAt` (`Instant`).
* `PushDeviceRepository`.
* `PushDeviceController`:
  * `PUT /api/v1/push/devices` body `{ platform, token }` — upsert by
    token. If the token exists under **another user** (shared device,
    logout→login), re-own it to the current user. Refreshes
    `lastRegisteredAt`, un-deletes if soft-deleted.
  * `DELETE /api/v1/push/devices/{token}` — soft-delete (called on
    logout so the next owner of the phone doesn't get the previous
    user's pushes).
* `service/PushDeviceService` + Impl (interface+impl per convention).

Flyway `V52__push_devices.sql`: table with the BaseEntity columns +
`user_id` FK, `platform varchar(20)`, `token varchar(200) unique`,
`last_registered_at timestamptz`, index on `user_id`.

### B2 — Sender abstraction + APNs impl

* `service/PushSender` interface:

```java
public interface PushSender {
    /** Sends to one device; returns DELIVERED, TOKEN_INVALID or FAILED. */
    PushSendResult send(PushDevice device, PushMessage message);
    boolean supports(PushPlatform platform);
}
```

* `PushMessage`: `title`, `body`, `Map<String,String> data` (deep-link
  payload, e.g. `type=scheduled_workout`).
* `ApnsPushSender` using Pushy: token auth from `PushProperties`
  (`push.apns.enabled`, `.key-path` (the `.p8`), `.key-id`, `.team-id`,
  `.bundle-id`, `.sandbox` flag for the dev APNs host). Follows
  `MailProperties`/`JwtProperties` shape; bean only created when
  `enabled=true` (`@ConditionalOnProperty`), so local dev and CI run
  without credentials. Maps APNs `BadDeviceToken` / `Unregistered` /
  `ExpiredToken` → `TOKEN_INVALID`.
* `FcmPushSender` using the Firebase Admin SDK (`supports(ANDROID)`):
  `FcmConfig` builds the `FirebaseApp` / `FirebaseMessaging` beans from
  `FcmProperties` (`push.fcm.enabled`, `.credentials-path` — the
  service-account JSON), both `@ConditionalOnProperty`-gated the same way.
  Maps FCM `UNREGISTERED` → `TOKEN_INVALID`; other `MessagingErrorCode`s →
  `FAILED`. Plugs into the existing `List<PushSender>` with no `PushService`
  change (that's the whole point of the seam).
* `service/PushService` + Impl — the facade other features call:
  `sendToUser(Long userId, PushMessage message)` fans out to all the
  user's non-deleted devices via the matching `PushSender` (`supports(platform)`).
  On `TOKEN_INVALID` soft-deletes the device row. A device whose platform
  has no configured sender (e.g. APNs off, or FCM off) is silently skipped.
  Failures are logged, never propagated — a push must never break the
  calling flow. Runs on a dedicated `pushTaskExecutor` (`@Async`).

### B3 — Workout reminder job

`WorkoutReminderJob` in `com.lifey.push/` (it's a push concern that reads
workout data, same as `TrainerClientCleanupJob` living where its data is):

* `@Scheduled(cron = "0 */15 * * * *")` — every 15 minutes, because
  "morning" differs per user offset; each run sends to users whose local
  clock has just passed the send hour.
* Candidate query (`WorkoutSessionRepository`): sessions with
  `startedAt IS NULL AND deletedAt IS NULL AND reminderSentAt IS NULL AND
  scheduledFor BETWEEN :yesterday AND :tomorrow` (UTC-date bounds wide
  enough to cover every offset), fetching the user's
  `utcOffsetMinutes`.
* In-Java filter per session: compute user-local now
  (`Instant.now() + offset`); send when `scheduledFor == user-local today
  && user-local time >= SEND_HOUR` (constant, `08:00`). Sessions whose
  local day already passed without a send (app deployed mid-day, job
  downtime) still match until midnight — reminders never carry over to
  the next day.
* Preference gate: skip users whose `UserSettings.workoutReminderEnabled`
  is `false` (see B3b). Skipped occurrences do **not** get
  `reminderSentAt` set — if the user re-enables the toggle before local
  midnight, the reminder still goes out that day.
* For each hit: set `reminderSentAt` **first**, save, then
  `pushService.sendToUser(...)` — a crash between the two loses one
  reminder rather than double-sending, the right failure mode for
  notifications.
* Copy localized by the `UserSettings` language (same resolve-with-EN-
  fallback as `MailLanguageResolver`; extract the enum mapping into a
  shared resolver or duplicate the two-line lookup — reviewer's choice).
  EN: title "Workout today", body "Push day at 18:00" / "Push day"
  (template name, `scheduledTime` appended when set). HU equivalent.
* Data payload: `type=scheduled_workout`, `sessionId`, `scheduledFor` —
  enough for the app to deep-link.

Flyway `V53__workout_session_reminder_sent.sql`:
`alter table workout_sessions add column reminder_sent_at timestamptz;`

### B3b — Workout reminder preference on `UserSettings`

* `UserSettings` gains `workoutReminderEnabled` (`boolean`, default
  `true` — opt-out: a trainer-scheduled workout is something the client
  signed up for, and the OS permission prompt is the real consent gate).
* Wire through `SettingsRequest`/`SettingsResponse` + `SettingsMapper`
  like every other settings field — no new endpoint, the existing
  `/settings` round-trip carries it.
* Flyway `V54__user_settings_workout_reminder.sql`:
  `alter table user_settings add column workout_reminder_enabled boolean
  not null default true;`
* Users with no `user_settings` row yet (it's created lazily) count as
  enabled — the job treats "no row" as the default, same as
  `MailLanguageResolver` does for language.

### B4 — Backend tests

* `PushDeviceController`/service: register upserts, re-owns a token
  registered to another user, delete soft-deletes; repository via
  Testcontainers.
* `PushServiceImpl`: fans out to all devices, soft-deletes on
  `TOKEN_INVALID`, swallows `FAILED` (mock `PushSender`).
* `WorkoutReminderJob` with an injected `Clock`: fires only after local
  08:00 per offset (test offsets −300, 0, +120), skips started/
  cancelled/already-reminded, marks `reminderSentAt`, correct
  local-date boundary around UTC midnight; skips a user with
  `workoutReminderEnabled=false` without marking `reminderSentAt`, and
  treats a missing `user_settings` row as enabled.
* No live-APNs / live-FCM test — `ApnsPushSender` and `FcmPushSender` stay
  thin adapters; their config wiring is covered by the context loading with
  both `enabled=false` (the default full-suite run). `PushServiceImpl`'s
  "skip a device whose platform has no sender" branch already exercises the
  Android-off / iOS-off paths with mock senders.

## Mobile plan

Two platform-specific registration paths (iOS via a native APNs channel,
Android via `firebase_messaging`) that both feed the **same** shared Dart
token lifecycle (M2), tap handling (M3), and settings screen (M5). The
backend endpoint (`PUT /api/v1/push/devices`) already accepts either
`platform: "IOS"` or `"ANDROID"`, so nothing server-side changes for
Android — this is purely mobile integration work.

### M1 — iOS: APNs registration via platform channel

* `Runner.entitlements`: add `aps-environment` (`development`; Xcode
  flips to `production` on distribution). Push Notifications capability
  must also be enabled on the App ID in the developer portal — same
  manual step already documented for App Groups.
* `AppDelegate.swift`: a `MethodChannel` (`lifey/push`) with:
  * `requestToken` → `UNUserNotificationCenter.requestAuthorization`
    (alert+sound+badge) then
    `registerForRemoteNotifications`; resolve the pending Flutter result
    from `didRegisterForRemoteNotificationsWithDeviceToken` (hex-encode)
    or reject from `didFailToRegister...`.
  * Tap forwarding: `userNotificationCenter(_:didReceive:)` passes
    `userInfo` to Flutter (`onPushTapped` invoke). Foreground pushes:
    `willPresent` → `.banner, .sound` so a reminder shows while the app
    is open. Note: `flutter_local_notifications` also installs a
    UNUserNotificationCenter delegate — the AppDelegate delegate methods
    must call through/coexist with it (set the delegate in AppDelegate
    and forward local-notification responses to the plugin, which the
    plugin supports; verify against the plugin's iOS setup docs during
    implementation).

### M1b — Android: FCM registration via `firebase_messaging` (DONE)

Android needs no custom platform channel — the `firebase_messaging`
package handles token retrieval and message callbacks.

* **Gradle / project wiring**:
  * `firebase_core: ^4.11.0` + `firebase_messaging: ^16.4.1` added to
    `pubspec.yaml` (versions resolved via `flutter pub get`, not guessed).
  * `android/settings.gradle.kts`: `com.google.gms.google-services` plugin
    declared (`apply false`) at version `4.5.0`.
  * `android/app/build.gradle.kts`: the plugin is applied **conditionally**
    — only `if (file("google-services.json").exists())` — so `flutter build`/
    `flutter run`/CI keep working exactly as before until a real file is
    dropped in; the google-services plugin hard-fails the build otherwise.
    Verified: `flutter build apk --debug` succeeds today (no file present).
  * `mobile/.gitignore`: `android/app/google-services.json` added — never
    committed (real values are tied to a specific Firebase project; see
    [devops/push-notifications-android.md](../devops/push-notifications-android.md)).
* **`POST_NOTIFICATIONS`** is already declared in the app's own manifest
  (used by the existing local notifications); `firebase_messaging`'s own
  manifest also declares it (merges fine, no conflict).
* **Token source**: `lib/core/push/push_token_source.dart` — a
  `PushTokenSource` interface (`platform` getter, `getToken()`,
  `onTokenRefreshed` stream) shared with the iOS side that M2 will add.
  `lib/core/push/android_push_token_source.dart` implements it:
  `getToken()` lazily calls `Firebase.initializeApp()` (guarded by
  `Firebase.apps.isEmpty`, mirroring the backend `FcmConfig`'s
  `FirebaseApp.getApps()` guard), then
  `FirebaseMessaging.instance.requestPermission()` (this is what actually
  triggers the Android 13+ `POST_NOTIFICATIONS` prompt — confirmed in the
  plugin's own Android source), returns `null` on denial, otherwise
  `FirebaseMessaging.instance.getToken()`. `onTokenRefreshed` exposes
  `FirebaseMessaging.instance.onTokenRefresh`. Everything no-ops
  (`Platform.isAndroid` guard) on iOS, which never touches Firebase.
* Wired into the shared registrar in M2 (below). Tap handling
  (`onMessageOpenedApp`/`getInitialMessage`) is still M3, not yet built.

Verified in this environment: `flutter pub get` resolved real package
versions, `flutter analyze` is clean, `flutter test` (131 tests) passes,
and `flutter build apk --debug` succeeds — with and without the Gradle
plugin guard exercised (no `google-services.json` present here).

### M2 — Token lifecycle on the Flutter side (shared) (DONE)

`lib/core/push/push_token_registrar.dart` — one registrar, platform-agnostic
over the `PushTokenSource` each platform implements
(`IosPushTokenSource`/`AndroidPushTokenSource`, both already existed from
M1/M1b — no interface change was needed).

* `register()`: gets the token from the platform source, `PUT`s
  `/api/v1/push/devices` (`{platform, token}`), and — on first call —
  subscribes to `onTokenRefreshed` so a later rotation re-`PUT`s without
  needing another `register()` call. Re-running is idempotent (the backend
  upserts by token). Called from `AuthController` after login/register/
  Google login (state set → `unawaited(pushTokenRegistrarProvider.register())`)
  and from `build()` (cold start while a stored access token already
  restores the session).
* `unregister()`: cancels the rotation subscription, then `DELETE`s
  `/push/devices/{token}` using the **last token a `PUT` actually
  succeeded with** (cached in-memory, not re-fetched from the platform —
  avoids a redundant native/permission round-trip at logout, and still
  deletes the right row even if permission was revoked in the meantime).
  Wired into `AuthController.logout()` **before** `_storage.clear()` — the
  request needs the still-valid access token to identify the caller.
* Permission denial (either platform): `getToken()` returns `null` →
  `register()` is a no-op. No nag UI; re-attempted next cold start/login.
* **Not implemented**: `FirebaseMessaging.instance.deleteToken()` on
  Android logout. Skipped as unnecessary — the backend already re-owns a
  shared device's token to whichever user's next `PUT` claims it
  (`PushDeviceServiceImpl#register`), so forcing a fresh token isn't
  needed for correctness, only cosmetic. Revisit only if that assumption
  turns out wrong in practice.
* Everything in the registrar is wrapped so it **never throws** — a push
  registration hiccup must not break login, cold start, or logout.

Tested: `test/core/push/push_token_registrar_test.dart` (10 cases, fake
`Dio` adapter + a hand-written `PushTokenSource` fake — matching this
codebase's existing no-mocking-package convention) — PUT on register,
skip on denial, survives a failing PUT/DELETE, re-PUTs on rotation, no
duplicate listener on repeated `register()`, DELETEs the right token,
no-op `unregister()` when nothing was registered or on repeat calls, and
rotations after `unregister()` no longer trigger a PUT. Full suite (141
tests) + `flutter analyze` + `flutter build apk --debug` all pass.

### M3 — Tap handling / deep link (shared) (DONE)

A single tap handler (`lib/core/push/push_tap_handler.dart`, `PushTapHandler`
+ `pushTapHandlerProvider`, watched in `app.dart` alongside
`workoutResumePromptProvider`) keyed on the `data` payload's `type`, fed by
both platforms:

* **iOS**: `onPushTapped` invoke from the native channel (warm taps) + a
  `getLaunchNotification` query at startup (cold-start taps) — same pattern
  the resume-prompt uses for its launch check.
  * **Backend bugfix found while wiring this up**: `ApnsPushSender` built
    the APNs payload with only `setAlertTitle`/`setAlertBody` — it never
    added `PushMessage.data()` as custom payload properties, so the
    `type`/`sessionId`/`scheduledFor` deep-link payload silently never
    reached iOS devices (FCM's sender already did this correctly via
    `.putAllData(message.data())`; only APNs was missing it). Fixed by
    calling `message.data().forEach(payloadBuilder::addCustomProperty)`
    before `.build()`. Without this fix, M3's entire premise — routing on
    `data['type']` — would've had nothing to read on iOS.
  * **Native wiring, iOS side**: `PushChannel.swift` gained
    `willPresent`/`didReceive`/`getLaunchNotification`; `AppDelegate.swift`
    now sets `UNUserNotificationCenter.current().delegate = self` and
    overrides `userNotificationCenter(_:willPresent:...)` /
    `userNotificationCenter(_:didReceive:...)`, splitting on
    `notification.request.trigger is UNPushNotificationTrigger` — a genuine
    remote push goes to `PushChannel`, anything else (the existing
    step-goal/workout-session **local** notifications) falls through to
    `super`, which `FlutterAppDelegate` forwards to
    `flutter_local_notifications` (confirmed via the Flutter engine source:
    `FlutterAppDelegate` conforms to `UNUserNotificationCenterDelegate`
    transitively through the `FlutterAppLifeCycleProvider` protocol it
    declares in `FlutterPlugin.h`, even though that conformance isn't
    directly visible in `FlutterAppDelegate.h` — verified by reading the
    engine source rather than assuming). This delegate wasn't set at all
    before this work, so — as a side effect — foreground presentation for
    the app's *existing* local notifications is now actually wired up
    correctly for the first time too.
* **Android**: `firebase_messaging` — `onMessageOpenedApp` (warm taps) +
  `getInitialMessage()` (cold-start taps), both behind the shared
  `ensureFirebaseInitialized()` bootstrap (`lib/core/push/firebase_bootstrap.dart`)
  so this can't race `PushTokenRegistrar`'s own Firebase init. Foreground
  display needed a local-notification bridge (FCM notification-type
  messages don't show while the app is foregrounded): `onMessage` calls
  `NotificationService.showPush(title, body, data)`, a new method on a new
  `push` Android channel; its payload round-trips the `data` map
  (JSON-encoded, prefixed `push:`) so tapping that bridged local
  notification still routes correctly via a new
  `NotificationService.setPushTapHandler` hook.
* Routing is platform-agnostic: `type == scheduled_workout` → `go_router`
  navigate to the workouts tab (session list where scheduled occurrences
  appear). Keep it tab-level — occurrence-level deep linking is a non-goal.

Verified: backend recompiles clean; the 21 existing push-related backend
unit tests still pass (Testcontainers-based tests couldn't be re-verified
in this pass — see note below, unrelated to this change). Mobile:
`flutter analyze` clean, full suite (141 tests) passes, `flutter build apk
--debug` succeeds. iOS side (Swift) reasoned through carefully against the
actual Flutter engine source (no Mac available to compile/run in this
environment) — still needs a real device pass per M6.

> Aside, unrelated to this work: a local Docker/Testcontainers environment
> hiccup (a stale `~/.testcontainers.properties` pointing at the wrong
> Windows named pipe for the active Docker Desktop context) blocked the
> Testcontainers-backed backend tests during this pass. Confirmed
> pre-existing and unrelated to the push changes — those same tests passed
> earlier in this session — so not chased further here.

### M4 — Morning weigh-in reminder (local, opt-in) (DONE)

* New dependencies: `timezone` (promoted from transitive to direct, per
  the plugin's own `depend_on_referenced_packages` recommendation) +
  `flutter_timezone` (the plugin has no way to determine the device's IANA
  zone name itself). Versions resolved via `flutter pub get`
  (`timezone: ^0.10.1`, `flutter_timezone: ^4.1.1`), not guessed.
* `NotificationService` gained: a `weigh_in_reminder` channel/id 3
  (default-importance), a lazy `_ensureTimezoneInitialized()` (calls
  `tzdata.initializeTimeZones()` + `tz.setLocalLocation` from
  `FlutterTimezone.getLocalTimezone()`, best-effort — falls back to `tz.local`'s
  UTC default if the IANA name somehow isn't in the bundled database),
  `scheduleWeighInReminder({hour, minute, title, body})` (returns whether
  it actually got scheduled, so a future caller can revert its own toggle
  UI on permission denial), and `cancelWeighInReminder()`.
  `matchDateTimeComponents: DateTimeComponents.time` + a computed
  `_nextInstanceOf(hour, minute)` give the daily repeat;
  `androidScheduleMode: inexactAllowWhileIdle` needs no exact-alarm
  permission.
* Android manifest: added `RECEIVE_BOOT_COMPLETED` +
  `ScheduledNotificationReceiver`/`ScheduledNotificationBootReceiver` (the
  plugin's README makes clear **both** are required for `zonedSchedule` to
  work at all — the plan only mentioned the boot receiver, but the
  non-boot one is equally required and was added too).
* New `lib/core/push/weigh_in_reminder_preferences.dart`
  (`WeighInReminderPreferences`, mirroring `HealthPreferences`'
  device-local-not-`UserSettings` shape exactly) for the enabled flag +
  chosen time, and `lib/core/push/weigh_in_reminder_controller.dart`
  (`WeighInReminderController.enable()`/`.disable()`) tying preferences +
  scheduling + localized copy (`AppLocalizations`, matching
  `StepGoalNotifier`'s no-`BuildContext` `lookupAppLocalizations` pattern)
  together — this is the exact surface M5's toggle/time-picker will call.
  New arb keys `weighInReminderNotificationTitle`/`Body` (EN + HU).
* `AuthController.logout()` now also cancels the reminder and clears its
  preference, mirroring the existing `healthPreferences.clear()` call —
  a device-local schedule shouldn't carry over to the next account on a
  shared device.
* No app-level "reschedule on cold start" logic needed: both Android's
  `AlarmManager` and iOS's `UNUserNotificationCenter` persist a repeating
  scheduled notification at the OS level, independent of the app process;
  the boot receiver above only covers the reboot case.
* Deliberate simplicity (unchanged from the original plan): it fires even
  if weight was already logged that day. Suppressing it would require
  rescheduling on every weight log — noted as a follow-up, not built.
* The opt-in toggle + time picker UI itself is M5's job, not built here —
  this delivers the complete, ready-to-call mechanism underneath it,
  same pattern as M2/M3 being built ahead of M5.

Verified: `flutter analyze` clean, full suite (141 tests, unchanged — no
new automated test for the scheduling call itself, see below) passes,
`flutter build apk --debug` succeeds with the new manifest
receivers/permission and packages in place.

No unit test was added for `scheduleWeighInReminder`/`_nextInstanceOf`
directly — matching the plan's own M6 note ("behind an injectable plugin
wrapper if cheap; otherwise manual") and this codebase's existing
practice of leaving `FlutterSecureStorage`-backed classes like
`HealthPreferences` untested for the same reason (the plugin is a static
singleton, not cheaply fakeable without introducing an abstraction this
plan didn't call for). Manual verification is deferred to M6, alongside
the other on-device checks.

### M5 — Notification settings screen (DONE)

New `NotificationSettingsScreen` in `features/settings/presentation/`,
reached from a "Notifications" `ListTile` (bell icon, chevron) in the
main settings screen's Integrations card. Pushed via
`Navigator.push(MaterialPageRoute(...))`, matching how every other
settings sub-screen in this codebase is reached (`ChangePasswordScreen`,
`OnboardingEditScreen`, `WaterSourcesScreen`) — **not** a `go_router`
route as originally sketched; the plan's `/settings/notifications`
suggestion didn't match the established convention, so the convention won.

Layout, top to bottom — implemented as-planned:

* **Master switch** — "All notifications", reflects `state.anyEnabled`
  (true if any of the three is on); toggling it calls
  `setAllEnabled(bool)`, which flips all three. No separate stored gate.
* **Per-type `SwitchListTile`s**:
  * *Workout reminder* — backed by `UserSettings.workoutReminderEnabled`
    (added to the Dart domain model with `copyWith`/`fromJson`/`toJson`).
    This surfaced more plumbing than the plan's "add the field" implied,
    because the mobile app is offline-first (see B3b's backend
    equivalent): the field also needed a **Drift column** (schema v24
    migration, `BoolColumn ... withDefault(true)`, mirroring the existing
    `language`/`dailyStepGoal` migrations), a `SettingsRepository`
    to/from-row mapping, and a `PullEngine._pullSettings` JSON mapping —
    the full offline-first round-trip, not just a DTO field. "Optimistic
    flip with rollback on failure" was reinterpreted for this
    architecture too: the mobile settings save writes to the local
    cache + outbox (`SettingsRepository`), never talking to the network
    directly, so there's no synchronous API call to roll back against —
    rollback here covers a local write failure, and the actual server
    sync happens later in the background regardless.
  * *Morning weigh-in reminder* — with the time picker row (via
    `showTimePicker`) shown beneath it while enabled, calling
    `WeighInReminderController.enable/disable` (M4).
  * *Step goal reached* — new toggle over the **existing** step-goal
    notification, default on. New
    `HealthPreferences.isStepGoalNotificationEnabled`/`setStepGoalNotificationEnabled`
    (alongside the existing step-goal-adjacent prefs there);
    `StepGoalNotifier._check()` now checks it before firing.
* Permission-denied footer: shown when an enable attempt's
  `setWeighInReminderEnabled`/`setAllEnabled` call reports the OS didn't
  actually schedule anything. **Scope-trimmed from the plan**: the
  "open system settings" deep-link button was dropped — the
  `app_settings` package (added for exactly this) turned out to ship
  with its Android module hard-pinned to `compileSdk 33` while its own
  transitive androidx deps (`fragment`, `window`, `activity`, ...)
  require 34+, breaking `flutter build apk` outright. Rather than
  patching around a broken third-party package for a minor convenience,
  the hint is text-only ("enable them in Settings"); the switches stay
  togglable either way, which was always the important part.

State handling: `notification_settings_controller.dart`
(`features/settings/application/`) — `NotificationSettingsState` (a
plain value object: `anyEnabled` getter + `copyWith`) composed from
`settingsControllerProvider` (server-synced, reactive) and the two
local-pref providers (read once per state rebuild, since
`FlutterSecureStorage` isn't stream-backed — each mutating method
re-derives `state` explicitly rather than relying on a stream).

i18n: new arb keys (EN + HU) for the screen/tile titles, master switch,
the three type labels + subtitles, the time-row label, and the
permission-denied hint.

Verified: `flutter analyze` clean; full suite (148 tests — 141 prior +
7 new for `NotificationSettingsState`'s `anyEnabled`/`copyWith`) passes;
`flutter build apk --debug` succeeds (after dropping `app_settings`, per
above). No test was added for `NotificationSettingsController` itself,
consistent with this codebase's existing practice of leaving
DB/secure-storage-backed controllers untested (`HealthController`,
`SettingsController` have none either) — only the pure state object
carries logic worth asserting on cheaply.

### M6 — Mobile tests

* Unit: `PushTokenRegistrar` (mock token source + dio) — registers after
  login with the right `platform` string, skips on denial, deletes on
  logout, re-`PUT`s on token rotation. Cover both an iOS-channel token
  source and a `firebase_messaging` one behind the same abstraction.
  **Done** (M2) — see `test/core/push/push_token_registrar_test.dart`.
* Unit: `notification_settings_controller` — **partially done**: the
  pure `NotificationSettingsState` (`anyEnabled`, `copyWith`) is covered
  (M5); the controller's own DB/secure-storage-backed methods are not,
  per the M5 note above.
* `NotificationService.scheduleWeighInReminder`/cancel behind an
  injectable plugin wrapper if cheap; otherwise manual. **Not done** —
  left for manual/device verification, per the M4 note.
* Manual device pass, **per platform** (iOS APNs needs a physical device;
  Android FCM works on an emulator with Play services): register → token
  row appears with the correct `platform`; trigger job (temporarily lower
  SEND_HOUR or insert a session) → push arrives, tap opens workouts tab;
  toggle weigh-in reminder → notification fires next morning, off cancels
  it; workout reminder off → job skips the user; master switch off →
  nothing fires. Verify a `TOKEN_INVALID` prune (uninstall/reinstall to
  invalidate a token, then send). **Not done in this environment** — no
  Mac (iOS) and no device/emulator session was run; this remains the one
  genuinely outstanding verification step across the whole plan.

## Non-goals (deferred)

* ~~FCM / Android remote push~~ — **no longer deferred.** The backend
  `FcmPushSender`, the Android app-side token source (M1b), the shared
  registrar (M2), and tap handling (M3) are all implemented for both
  platforms. M1–M5 are done end to end; only the M6 manual device pass
  remains.
* Trainer comment push (#13) — first consumer of `PushService` after
  this lands; when it arrives, it gets its own switch on the M5 screen
  (and, if remote types multiply, that's the trigger to generalize
  server-side preferences).
* "Open system settings" deep-link from the permission-denied hint —
  dropped in M5 due to a broken `app_settings` package release (see M5).
  Revisit if a fixed version ships, or with `permission_handler` if that
  turns out more reliable.
* A generic server-side preference center (per-type rows, schedules) —
  one boolean on `UserSettings` covers the single remote type for now.
* Rich push (images, actions), badge counts, quiet hours.
* Occurrence-level deep links; skipping the weigh-in reminder when
  weight is already logged (M4 follow-up).
* Web admin changes — none.

## Edge cases

* **Multiple devices per user** — `sendToUser` fans out to all
  registered, non-deleted devices; each invalid token is pruned
  individually.
* **Shared device / user switch** — register re-owns the token to the
  new user; logout deletes it. Worst case (force-quit before logout
  completes): next login's upsert re-owns it anyway.
* **Token rotation** — iOS re-delivers the token on each
  `registerForRemoteNotifications`; Android fires `onTokenRefresh`. The
  cold-start re-register (M2) keeps the row current on both, and a stale
  token dies via `TOKEN_INVALID` pruning (APNs `BadDeviceToken` /
  `Unregistered`, FCM `UNREGISTERED`).
* **FCM project mismatch** — the app's `google-services.json` and the
  backend's service-account key must be from the **same** Firebase
  project, or every Android send fails with `SENDER_ID_MISMATCH` (logged,
  swallowed, not user-facing). Ops concern, flagged in
  [devops/push-notifications-android.md](../devops/push-notifications-android.md).
* **User changes timezone** — `utc_offset_minutes` updates on the next
  auth flow (login/refresh), so the send window follows the user with
  at most a token-refresh lag. Acceptable for a morning reminder.
* **Session scheduled for today, created after 08:00** — the next
  15-min job tick catches it (local time is already past SEND_HOUR).
* **Occurrence cancelled after the reminder went out** — acceptable; the
  reminder was true when sent. Cancelled *before* → excluded by
  `deletedAt IS NULL`.
* **Client already did the workout early** — `startedAt IS NOT NULL`
  excludes it; no reminder for a done session.
* **Job overlap / restart** — `reminderSentAt` is written before the
  send, so re-runs can't double-send; a crash in the gap loses at most
  that one reminder.
* **APNs outage / misconfig** — `PushService` logs and swallows; the
  job marks and moves on; nothing user-facing breaks.
* **App not released** — no backward-compat concern for the new
  endpoint or migrations (per project memory).

## Test plan summary

Backend: B4 (Mockito unit tests with injected `Clock`, Testcontainers for
the repository, no live APNs/FCM — both adapters are covered by context
loading with the senders disabled). Mobile: M6 (unit for the registrar and
the notification-settings controller; per-platform manual device pass — a
physical device for iOS APNs, an emulator for Android FCM).

## Suggested PR split

1. **Backend — push package + APNs sender** (B1, B2, B4 minus job
   tests): registration API + `PushService`, mergeable with `enabled=false`
   everywhere.
2. **Backend — workout reminder job + settings flag** (B3, B3b + job
   tests): depends on PR 1.
3. **Mobile — iOS APNs registration + shared token lifecycle + tap
   handling** (M1, M2, M3): depends on PR 1 for the endpoint; testable
   against a sandbox APNs key on a physical device.
4. **Mobile — Android FCM registration** (M1b): `firebase_messaging` +
   `google-services.json` + Gradle plugin, feeding the same M2/M3 built in
   PR 3. Depends on PR 1 (endpoint) and the backend `PUSH_FCM_*` config
   being set where the app points. Testable on an emulator.
5. **Mobile — notification settings screen + local reminders** (M4, M5):
   the screen, the weigh-in reminder and the step-goal toggle are purely
   local and can land any time; the workout-reminder switch needs PR 2's
   settings field on the backend it points at (until then, ship the
   screen without that row or behind the field's presence in the
   response — implementer's choice).

PR 3 and PR 4 can be parallel once the shared M2/M3 abstraction from PR 3
is agreed (or land M2/M3's interface first). Backend PRs 1–2 (APNs + FCM
senders, reminder job) are **already implemented**.

Rough effort: the genuinely new ground left is the two mobile registration
paths (native APNs channel in PR 3, `firebase_messaging` wiring in PR 4);
the backend follows existing patterns and is done.
