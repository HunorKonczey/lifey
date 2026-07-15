import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../notifications/notification_service.dart';

/// Mutable per-update state for the running workout session. Feeds both
/// platform mechanisms: the iOS Live Activity content state (mirrors the
/// Swift `WorkoutActivityAttributes.ContentState`,
/// docs/24-ios-widget-live-activity-plan.md) and the Android ongoing
/// notification's body/anchor (docs/25-android-widget-ongoing-notification-plan.md).
class WorkoutSessionState {
  const WorkoutSessionState({
    required this.exerciseName,
    required this.setsDone,
    this.setsTotal,
    required this.totalSetsDone,
    this.lastSetAtEpochMs,
    this.restEndsAtEpochMs,
  });

  /// Current (last touched) exercise name; pass a pre-localized fallback
  /// (e.g. "Gyakorlat") for the empty-block case rather than an empty string.
  final String exerciseName;
  final int setsDone;
  final int? setsTotal;
  final int totalSetsDone;
  final int? lastSetAtEpochMs;

  /// The rest timer's target end time, epoch ms — null when the rest timer
  /// is disabled, skipped, or already expired (docs/39-rest-timer-plan.md
  /// §Prompt 5). When present, both native surfaces render a countdown to it
  /// instead of the plain count-up from [lastSetAtEpochMs].
  final int? restEndsAtEpochMs;

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'setsDone': setsDone,
        'setsTotal': setsTotal,
        'totalSetsDone': totalSetsDone,
        'lastSetAtEpochMs': lastSetAtEpochMs,
        'restEndsAtEpochMs': restEndsAtEpochMs,
      };
}

/// Platform-neutral facade over both "ongoing workout indicator" mechanisms:
///
/// - **iOS**: hand-rolled `lifey/live_activity` MethodChannel → ActivityKit
///   (docs/24-ios-widget-live-activity-plan.md, "Hand-rolled MethodChannel").
/// - **Android**: [NotificationService]'s silent ongoing notification on the
///   `workout_session` channel — Android's stand-in for a Live Activity,
///   since content only changes while the app is foregrounded and the
///   ticking timer is rendered natively via `usesChronometer`
///   (docs/25-android-widget-ongoing-notification-plan.md, decision #2/#3).
/// - Other platforms: no-op.
///
/// Same call sites regardless of platform — [LogSessionScreen],
/// `WorkoutResumePrompt`, `SessionsTab` — this service picks the native
/// mechanism.
class WorkoutSessionNotifierService {
  WorkoutSessionNotifierService({
    MethodChannel? channel,
    bool? isAvailable,
    bool? useAndroidBranch,
    Future<bool> Function()? requestAndroidPermission,
    Future<void> Function({
      required String title,
      required String body,
      required String subText,
      required int whenEpochMs,
      bool chronometerCountDown,
    })? showAndroidNotification,
    Future<void> Function()? cancelAndroidNotification,
  })  : _channel = channel ?? const MethodChannel('lifey/live_activity'),
        isAvailable = isAvailable ?? (Platform.isIOS || Platform.isAndroid),
        _useAndroid = useAndroidBranch ?? Platform.isAndroid,
        _requestAndroidPermission =
            requestAndroidPermission ?? NotificationService.requestWorkoutSessionPermission,
        _showAndroidNotificationCall =
            showAndroidNotification ?? NotificationService.showWorkoutSession,
        _cancelAndroidNotification =
            cancelAndroidNotification ?? NotificationService.cancelWorkoutSession;

  final MethodChannel _channel;

  /// Defaults to [Platform.isIOS] || [Platform.isAndroid]; overridable in
  /// the constructor so tests can exercise calls on other test hosts.
  final bool isAvailable;

  /// Defaults to [Platform.isAndroid]; overridable in the constructor so
  /// tests (which run on a non-Android host) can exercise the Android
  /// branch against the injected callables below.
  final bool _useAndroid;

  // Android-only calls, injectable so tests can assert on them without
  // touching the real flutter_local_notifications platform channel — same
  // pattern as WidgetSnapshotWriter.
  final Future<bool> Function() _requestAndroidPermission;
  final Future<void> Function({
    required String title,
    required String body,
    required String subText,
    required int whenEpochMs,
    bool chronometerCountDown,
  }) _showAndroidNotificationCall;
  final Future<void> Function() _cancelAndroidNotification;

  // Android only: the iOS channel re-sends title/startedAt on every call,
  // but the Android notification only receives them at start() — cached
  // here so update() can rebuild the "when" anchor and subText.
  String? _androidTitle;
  DateTime? _androidStartedAt;

  /// Starts tracking [sessionClientId]. Returns the native activity id on
  /// iOS, or null on Android/no-op (Android has no activity id concept).
  Future<String?> start({
    required String sessionClientId,
    required String title,
    required DateTime startedAt,
    required String startedLabel,
    required WorkoutSessionState state,
  }) async {
    if (!isAvailable) return null;

    if (_useAndroid) {
      _androidTitle = title;
      _androidStartedAt = startedAt;
      final granted = await _requestAndroidPermission();
      // Denied → the service silently no-ops; the workout itself is
      // unaffected (docs/25-android-widget-ongoing-notification-plan.md).
      if (!granted) return null;
      await _renderAndroidNotification(state, startedLabel);
      return null;
    }

    return _channel.invokeMethod<String>('start', {
      'sessionClientId': sessionClientId,
      'title': title,
      'startedAtEpochMs': startedAt.millisecondsSinceEpoch,
      'state': state.toJson(),
    });
  }

  /// Updates the running session's content state. No-ops (native side) if
  /// none is found (iOS) or if [start] was never called / was denied
  /// (Android).
  Future<void> update({
    required String sessionClientId,
    required String startedLabel,
    required WorkoutSessionState state,
  }) async {
    if (!isAvailable) return;

    if (_useAndroid) {
      await _renderAndroidNotification(state, startedLabel);
      return;
    }

    await _channel.invokeMethod('update', {
      'sessionClientId': sessionClientId,
      'state': state.toJson(),
    });
  }

  /// Ends the current workout's indicator immediately.
  Future<void> end() async {
    if (!isAvailable) return;
    if (_useAndroid) {
      _androidTitle = null;
      _androidStartedAt = null;
      await _cancelAndroidNotification();
      return;
    }
    await _channel.invokeMethod('end');
  }

  /// Safety sweep: ends every orphaned indicator. Called once on app start
  /// when no in-progress session was found (see `WorkoutResumePrompt`).
  Future<void> endAll() async {
    if (!isAvailable) return;
    if (_useAndroid) {
      await _cancelAndroidNotification();
      return;
    }
    await _channel.invokeMethod('endAll');
  }

  Future<void> _renderAndroidNotification(WorkoutSessionState state, String startedLabel) async {
    final title = _androidTitle;
    final startedAt = _androidStartedAt;
    if (title == null || startedAt == null) return;

    // A known, still-future rest-timer target renders as a countdown
    // (docs/39-rest-timer-plan.md, Prompt 5); otherwise decision #3
    // (docs/25-android-widget-ongoing-notification-plan.md) applies: before
    // the first logged set the chronometer shows elapsed time from
    // startedAt, after each set a rest count-up from the last set.
    final restEndsAt = state.restEndsAtEpochMs;
    final useRestCountdown =
        restEndsAt != null && restEndsAt > DateTime.now().millisecondsSinceEpoch;
    final whenEpochMs = useRestCountdown
        ? restEndsAt
        : (state.lastSetAtEpochMs ?? startedAt.millisecondsSinceEpoch);
    final body = state.setsTotal != null
        ? '${state.exerciseName} · ${state.setsDone}/${state.setsTotal}'
        : state.exerciseName;
    final subText = '$startedLabel ${DateFormat('HH:mm').format(startedAt.toLocal())}';

    await _showAndroidNotificationCall(
      title: title,
      body: body,
      subText: subText,
      whenEpochMs: whenEpochMs,
      chronometerCountDown: useRestCountdown,
    );
  }
}

final workoutSessionNotifierServiceProvider = Provider<WorkoutSessionNotifierService>((ref) {
  return WorkoutSessionNotifierService();
});
