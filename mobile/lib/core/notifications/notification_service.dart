import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
    await _plugin.initialize(settings);
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
    );
  }

  /// Cancels the ongoing workout-session notification (Android only).
  static Future<void> cancelWorkoutSession() async {
    if (!Platform.isAndroid) return;
    await _plugin.cancel(_workoutSessionNotificationId);
  }
}
