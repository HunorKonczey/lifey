import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper around [FlutterLocalNotificationsPlugin], shared by the
/// step-goal notification and the Android ongoing workout-session
/// notification (see docs/25-android-widget-ongoing-notification-plan.md —
/// Android's stand-in for the iOS Live Activity, driven by
/// `WorkoutSessionNotifierService`). All methods are no-ops on platforms
/// they don't apply to.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const workoutSessionChannelId = 'workout_session';
  static const stepGoalChannelId = 'step_goal';

  static const _stepGoalNotificationId = 1;
  static const _workoutSessionNotificationId = 2;
  static const _weighInReminderNotificationId = 3;

  // Distinguishes a tap on the workout-session notification from a tap on
  // the step-goal one in [onDidReceiveNotificationResponse] below.
  static const _workoutSessionPayload = 'workout_session_tap';

  // Distinguishes a tap on the weigh-in reminder notification from the other
  // fixed payload strings below.
  static const _weighInReminderPayload = 'weigh_in_reminder_tap';

  // Prefix distinguishing a push-bridge notification's payload (see
  // [showPush]) from the other two fixed payload strings above — the
  // remainder is the push's JSON-encoded `data` map.
  static const _pushPayloadPrefix = 'push:';

  // Set by `WorkoutResumePrompt` (read at tap time, not at [init] time, so
  // it doesn't matter which of the two runs first).
  static void Function()? _onWorkoutSessionTapped;

  // Set by the weigh-in reminder tap handler — fires when the user taps the
  // daily weigh-in reminder, so it can route to the weight tab.
  static void Function()? _onWeighInReminderTapped;

  // Set by the push tap handler (docs/30-push-notifications-plan.md, M3) —
  // fires when the user taps a notification shown via [showPush], i.e. an
  // Android FCM message that arrived while the app was foregrounded.
  static void Function(Map<String, dynamic> data)? _onPushTapped;

  /// Registers the callback fired when the user taps the ongoing
  /// workout-session notification while the app process is alive (Android's
  /// stand-in for the iOS Live Activity/Dynamic Island tap — see
  /// docs/25-android-widget-ongoing-notification-plan.md). Cold-start taps
  /// aren't covered here; `WorkoutResumePrompt`'s launch check already
  /// reopens an active session unconditionally on cold start.
  static void setWorkoutSessionTapHandler(void Function()? handler) {
    _onWorkoutSessionTapped = handler;
  }

  /// Registers the callback fired when the user taps the daily weigh-in
  /// reminder notification.
  static void setWeighInReminderTapHandler(void Function()? handler) {
    _onWeighInReminderTapped = handler;
  }

  /// Registers the callback fired when the user taps a [showPush]
  /// notification (docs/30-push-notifications-plan.md, M3).
  static void setPushTapHandler(void Function(Map<String, dynamic> data)? handler) {
    _onPushTapped = handler;
  }

  static const _workoutSessionChannel = AndroidNotificationChannel(
    workoutSessionChannelId,
    'Workout session',
    description: 'Ongoing progress while a workout session is active',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
    showBadge: false,
  );

  static const _stepGoalChannel = AndroidNotificationChannel(
    stepGoalChannelId,
    'Step goal',
    description: 'Notified once when you reach your daily step goal',
  );

  static const _pushChannelId = 'push';
  static const _pushChannel = AndroidNotificationChannel(
    _pushChannelId,
    'Push notifications',
    description: 'Notifications sent by the server (workout reminders, etc.)',
  );

  static const weighInReminderChannelId = 'weigh_in_reminder';
  static const _weighInReminderChannel = AndroidNotificationChannel(
    weighInReminderChannelId,
    'Weigh-in reminder',
    description: 'Daily reminder to log today\'s weight',
  );

  static bool _tzInitialized = false;

  /// Sets up the `timezone` package's local location so
  /// [scheduleWeighInReminder]'s `zonedSchedule` calls fire at the device's
  /// actual wall-clock time (and follow DST) rather than a fixed offset.
  /// Best-effort: if the device's IANA name isn't in the bundled tz database
  /// (shouldn't happen in practice), `tz.local` just stays at its UTC
  /// default — the reminder would then fire at the wrong wall-clock time
  /// rather than not at all, an acceptable degradation for a morning nudge.
  static Future<void> _ensureTimezoneInitialized() async {
    if (_tzInitialized) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      // See doc comment above.
    }
    _tzInitialized = true;
  }

  /// Must be called once before any other call on this class. Safe to call
  /// multiple times — subsequent calls are no-ops.
  static Future<void> init() async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_lifey'),
      iOS: DarwinInitializationSettings(
        // We never request permissions here: the Health connect flow
        // (Connect Health) is the user's opt-in signal. The notification
        // permission dialog is shown by iOS the first time a notification
        // fires; on Android it's requested lazily per-channel (see
        // _ensureAndroidChannel) the first time each notification type fires.
        requestAlertPermission: true,
        requestBadgePermission: false,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload == _workoutSessionPayload) {
          _onWorkoutSessionTapped?.call();
        } else if (payload == _weighInReminderPayload) {
          _onWeighInReminderTapped?.call();
        } else if (payload != null && payload.startsWith(_pushPayloadPrefix)) {
          final data = jsonDecode(payload.substring(_pushPayloadPrefix.length));
          _onPushTapped?.call((data as Map).cast<String, dynamic>());
        }
      },
    );
  }

  /// Creates [channel] if needed and requests Android 13+
  /// `POST_NOTIFICATIONS` (a single app-wide permission — requesting it
  /// again for a second channel is a no-op once already granted). Returns
  /// whether notifications can actually be shown. Android only.
  static Future<bool> _ensureAndroidChannel(AndroidNotificationChannel channel) async {
    if (!Platform.isAndroid) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Posts a "step goal reached" local notification with [title] and [body].
  static Future<void> showGoalReached({
    required String title,
    required String body,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    if (Platform.isAndroid && !await _ensureAndroidChannel(_stepGoalChannel)) return;

    await _plugin.show(
      _stepGoalNotificationId, // fixed ID so re-firing replaces the previous banner
      title,
      body,
      NotificationDetails(
        android: Platform.isAndroid
            ? const AndroidNotificationDetails(
                stepGoalChannelId,
                'Step goal',
                channelDescription: 'Notified once when you reach your daily step goal',
              )
            : null,
        iOS: Platform.isIOS ? const DarwinNotificationDetails() : null,
      ),
    );
  }

  /// Ensures the `workout_session` channel exists and requests Android 13+
  /// `POST_NOTIFICATIONS` (no-op, already-granted-safe on older Android).
  /// Returns whether the notification can actually be shown.
  static Future<bool> requestWorkoutSessionPermission() =>
      _ensureAndroidChannel(_workoutSessionChannel);

  /// Shows/updates the ongoing workout-session notification (Android only;
  /// see [WorkoutSessionNotifierService]'s Android branch for the
  /// title/body/subText/`when` it passes in).
  static Future<void> showWorkoutSession({
    required String title,
    required String body,
    required String subText,
    required int whenEpochMs,
  }) async {
    if (!Platform.isAndroid) return;
    await _plugin.show(
      _workoutSessionNotificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          workoutSessionChannelId,
          'Workout session',
          channelDescription: 'Ongoing progress while a workout session is active',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          ongoing: true,
          onlyAlertOnce: true,
          autoCancel: false,
          showWhen: true,
          when: whenEpochMs,
          usesChronometer: true,
          subText: subText,
          category: AndroidNotificationCategory.workout,
        ),
      ),
      payload: _workoutSessionPayload,
    );
  }

  /// Cancels the ongoing workout-session notification (Android only).
  static Future<void> cancelWorkoutSession() async {
    if (!Platform.isAndroid) return;
    await _plugin.cancel(_workoutSessionNotificationId);
  }

  /// Surfaces a remote push as a local notification banner — Android only.
  /// FCM's own "notification" payload is auto-displayed by the OS while the
  /// app is backgrounded/terminated, but never while it's foregrounded, so a
  /// foreground FCM message needs this bridge to be seen at all (see
  /// docs/30-push-notifications-plan.md, M3; iOS shows the push natively via
  /// its own `willPresent` handling instead — no bridge needed there).
  /// [data] is the push's deep-link payload, round-tripped through the
  /// notification's payload so a tap on it still routes correctly.
  static Future<void> showPush({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    if (!Platform.isAndroid) return;
    if (!await _ensureAndroidChannel(_pushChannel)) return;

    await _plugin.show(
      // Distinct ID per push (unlike the fixed step-goal/workout-session
      // ones) so multiple pushes don't replace each other in the tray.
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _pushChannelId,
          'Push notifications',
          channelDescription: 'Notifications sent by the server (workout reminders, etc.)',
        ),
      ),
      payload: '$_pushPayloadPrefix${jsonEncode(data)}',
    );
  }

  /// Schedules (or reschedules, if already active) the daily morning
  /// weigh-in reminder at [hour]:[minute] local time
  /// (docs/30-push-notifications-plan.md, M4). Recurs daily via
  /// `matchDateTimeComponents`, but each call re-targets the *next*
  /// occurrence, so callers re-invoke this (see `WeighInReminderController
  /// .refreshForToday`) whenever they need to skip today's — e.g. weight was
  /// already logged today ([skipToday]). Returns whether it was actually
  /// scheduled (false on permission denial).
  static Future<bool> scheduleWeighInReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
    bool skipToday = false,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    if (Platform.isAndroid && !await _ensureAndroidChannel(_weighInReminderChannel)) {
      return false;
    }
    await _ensureTimezoneInitialized();

    await _plugin.zonedSchedule(
      _weighInReminderNotificationId,
      title,
      body,
      _nextInstanceOf(hour: hour, minute: minute, skipToday: skipToday),
      NotificationDetails(
        android: Platform.isAndroid
            ? const AndroidNotificationDetails(
                weighInReminderChannelId,
                'Weigh-in reminder',
                channelDescription: 'Daily reminder to log today\'s weight',
              )
            : null,
        iOS: Platform.isIOS ? const DarwinNotificationDetails() : null,
      ),
      // No exact-alarm permission required (unlike alarmClock/exact*) — a
      // morning nudge landing a few minutes late is fine.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: _weighInReminderPayload,
    );
    return true;
  }

  /// Cancels the daily weigh-in reminder.
  static Future<void> cancelWeighInReminder() async {
    await _plugin.cancel(_weighInReminderNotificationId);
  }

  /// The next occurrence of [hour]:[minute] in `tz.local` — today if that
  /// time hasn't passed yet, otherwise tomorrow. Forced to tomorrow
  /// regardless of the time if [skipToday] is set (weight already logged
  /// today). `zonedSchedule` then repeats it daily via
  /// `matchDateTimeComponents: DateTimeComponents.time`.
  static tz.TZDateTime _nextInstanceOf({
    required int hour,
    required int minute,
    bool skipToday = false,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (skipToday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
