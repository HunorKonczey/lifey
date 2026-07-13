import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/workouts/data/workout_session_repository.dart';
import '../../features/workouts/presentation/log_session_screen.dart';
import '../notifications/notification_service.dart';
import '../router/app_router.dart';
import 'firebase_bootstrap.dart';

/// Routes a tap on a push notification to the right screen, on both
/// platforms and for both a warm tap (app already running) and a cold-start
/// tap (app was launched by it) — docs/30-push-notifications-plan.md, M3.
///
/// `type == scheduled_workout` just navigates to the workouts tab (where the
/// scheduled-occurrence list lives) — occurrence-level deep linking for that
/// type is a non-goal. `type == trainer_comment` is the one exception: it
/// opens the exact commented session on top of the workouts tab when it's
/// already synced locally (docs/31-session-feedback-loop-plan.md), falling
/// back to just the tab otherwise (e.g. the push beat the next pull).
/// `type == nutrition_goals` navigates to the nutrition tab — tab-level like
/// `scheduled_workout`, the next sync (already in flight by the time the tap
/// is handled) fills in the updated goals (docs/32-trainer-nutrition-goals-plan.md).
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
    if (data['type'] == 'trainer_comment') {
      unawaited(_routeToCommentedSession(data));
      return;
    }
    if (data['type'] == 'scheduled_workout') {
      _ref.read(appRouterProvider).go('/workouts');
    }
    if (data['type'] == 'nutrition_goals') {
      _ref.read(appRouterProvider).go('/nutrition');
    }
  }

  Future<void> _routeToCommentedSession(Map<String, dynamic> data) async {
    final sessionId = int.tryParse('${data['sessionId']}');
    final session = sessionId != null
        ? await _ref.read(workoutSessionRepositoryProvider).findByServerId(sessionId)
        : null;

    _ref.read(appRouterProvider).go('/workouts');
    if (session != null) {
      rootNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => LogSessionScreen(session: session)),
      );
    }
  }
}

final pushTapHandlerProvider = Provider<PushTapHandler>((ref) {
  final handler = PushTapHandler(ref);
  ref.onDispose(handler.dispose);
  return handler;
});
