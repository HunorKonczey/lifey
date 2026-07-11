import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/notification_service.dart';
import '../router/app_router.dart';
import 'firebase_bootstrap.dart';

/// Routes a tap on a push notification to the right screen, on both
/// platforms and for both a warm tap (app already running) and a cold-start
/// tap (app was launched by it) — docs/30-push-notifications-plan.md, M3.
///
/// Kept tab-level by design: `type == scheduled_workout` just navigates to
/// the workouts tab (where the scheduled-occurrence list already lives).
/// Occurrence-level deep linking is a non-goal.
///
/// Singleton for the app's lifetime (like `WorkoutResumePrompt`) — wired up
/// once via `ref.watch(pushTapHandlerProvider)` in `app.dart`.
class PushTapHandler {
  PushTapHandler(this._ref) {
    if (Platform.isIOS) {
      _iosChannel.setMethodCallHandler(_handleIosMethodCall);
      unawaited(_checkIosLaunchNotification());
    }
    if (Platform.isAndroid) {
      unawaited(_setupAndroid());
    }
  }

  final Ref _ref;

  static const _iosChannel = MethodChannel('lifey/push');

  StreamSubscription<RemoteMessage>? _androidTapSubscription;
  StreamSubscription<RemoteMessage>? _androidForegroundSubscription;

  void dispose() {
    unawaited(_androidTapSubscription?.cancel());
    unawaited(_androidForegroundSubscription?.cancel());
    NotificationService.setPushTapHandler(null);
  }

  Future<void> _setupAndroid() async {
    // Must complete before touching any FirebaseMessaging API — this runs
    // independently of (and possibly before/after/concurrently with)
    // PushTokenRegistrar's own Firebase init, hence the shared, memoized
    // bootstrap rather than each doing its own unguarded init.
    await ensureFirebaseInitialized();

    _androidTapSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _route(message.data),
    );
    // Foreground FCM messages don't auto-display (see
    // NotificationService.showPush) and aren't covered by
    // onMessageOpenedApp/getInitialMessage (those only fire for a tap that
    // brought the app to the foreground/launched it) — a foreground message
    // can only be acted on by tapping the bridged local notification, whose
    // tap is wired in NotificationService itself.
    _androidForegroundSubscription = FirebaseMessaging.onMessage.listen(_showForegroundMessage);
    NotificationService.setPushTapHandler(_route);

    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) _route(message.data);
  }

  Future<void> _handleIosMethodCall(MethodCall call) async {
    if (call.method != 'onPushTapped') return;
    final data = (call.arguments as Map?)?.cast<String, dynamic>();
    if (data != null) _route(data);
  }

  Future<void> _checkIosLaunchNotification() async {
    final data = await _iosChannel.invokeMethod<Map>('getLaunchNotification');
    if (data != null) _route(data.cast<String, dynamic>());
  }

  Future<void> _showForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await NotificationService.showPush(
      title: notification.title ?? '',
      body: notification.body ?? '',
      data: message.data,
    );
  }

  void _route(Map<String, dynamic> data) {
    if (data['type'] == 'scheduled_workout') {
      _ref.read(appRouterProvider).go('/workouts');
    }
  }
}

final pushTapHandlerProvider = Provider<PushTapHandler>((ref) {
  final handler = PushTapHandler(ref);
  ref.onDispose(handler.dispose);
  return handler;
});
