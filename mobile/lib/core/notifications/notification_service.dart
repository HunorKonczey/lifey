import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around [FlutterLocalNotificationsPlugin] for the iOS-only
/// step-goal notification. All methods are no-ops on non-iOS platforms.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Must be called once before any [showGoalReached] calls. Safe to call
  /// multiple times — subsequent calls are no-ops.
  static Future<void> init() async {
    if (!Platform.isIOS) return;
    const settings = InitializationSettings(
      iOS: DarwinInitializationSettings(
        // We never request permissions here: the HealthKit permission flow
        // (Connect Apple Health) is the user's opt-in signal. The notification
        // permission dialog is shown by iOS the first time a notification fires.
        requestAlertPermission: true,
        requestBadgePermission: false,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(settings);
  }

  /// Posts a "step goal reached" local notification with [title] and [body].
  static Future<void> showGoalReached({
    required String title,
    required String body,
  }) async {
    if (!Platform.isIOS) return;
    await _plugin.show(
      1, // fixed ID so re-firing replaces the previous banner
      title,
      body,
      const NotificationDetails(iOS: DarwinNotificationDetails()),
    );
  }
}
