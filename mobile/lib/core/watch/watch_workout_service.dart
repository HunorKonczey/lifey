import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../workout_session_notifier/workout_session_notifier_service.dart' show WorkoutSessionState;

/// Enrichment payload a watch app sends back once its side of a workout ends
/// (docs/40-watch-app-plan.md §6.3). [sessionClientId] ties it back to the
/// Drift-cached session the phone already owns; the fields line up 1:1 with
/// [WorkoutSession]'s health-enrichment columns.
class WatchWorkoutSummary {
  const WatchWorkoutSummary({
    required this.sessionClientId,
    this.activeCalories,
    this.averageHeartRate,
    this.healthWorkoutId,
  });

  final String sessionClientId;
  final double? activeCalories;
  final double? averageHeartRate;
  final String? healthWorkoutId;

  factory WatchWorkoutSummary.fromJson(Map<Object?, Object?> json) => WatchWorkoutSummary(
        sessionClientId: json['sessionClientId'] as String,
        activeCalories: (json['activeCalories'] as num?)?.toDouble(),
        averageHeartRate: (json['averageHeartRate'] as num?)?.toDouble(),
        healthWorkoutId: json['healthWorkoutId'] as String?,
      );
}

/// The watch declined to start its own session — e.g. another app's exercise
/// is already running on Wear OS (docs/40-watch-app-plan.md §5.3, §8.1).
class WatchStartRejected {
  const WatchStartRejected(this.sessionClientId);
  final String sessionClientId;
}

/// The user pressed "End" on the watch — the watch never closes its own
/// session unilaterally, it asks the phone to (docs/40-watch-app-plan.md
/// §8.2 decision (b)), so the phone's normal finish flow (RPE/feedback
/// sheet) still runs. Handled by [LogSessionScreen] while its instance for
/// this [sessionClientId] is mounted; a no-op otherwise.
class WatchEndRequested {
  const WatchEndRequested(this.sessionClientId);
  final String sessionClientId;
}

/// Platform-neutral facade over the phone↔watch workout bridge
/// (docs/40-watch-app-plan.md §6.1). Mirrors [WorkoutSessionNotifierService]'s
/// shape and constructor-injection pattern so it can be called side by side
/// from the same screens without a shared coordination layer — start/update/
/// end here drive the *watch's own* strength-workout session, independently
/// of the Live Activity / ongoing-notification indicator.
///
/// Every native call is best-effort and never throws: until the native watch
/// targets exist (docs/40-watch-app-plan.md phases F2/F3), the underlying
/// `MethodChannel` has no handler and calling it throws
/// `MissingPluginException` — caught and swallowed here exactly like a
/// missing/unpaired watch, so the phone-side workout is never affected by the
/// watch bridge being absent or not yet implemented natively.
class WatchWorkoutService {
  WatchWorkoutService({
    MethodChannel? channel,
    EventChannel? eventChannel,
    bool? isAvailable,
  })  : _channel = channel ?? const MethodChannel('lifey/watch'),
        _eventChannel = eventChannel ?? const EventChannel('lifey/watch/events'),
        isAvailable = isAvailable ?? (Platform.isIOS || Platform.isAndroid);

  final MethodChannel _channel;
  final EventChannel _eventChannel;

  /// Defaults to [Platform.isIOS] || [Platform.isAndroid]; overridable in the
  /// constructor so tests can exercise calls on a non-mobile test host.
  final bool isAvailable;

  Stream<Object>? _events;

  /// Emits [WatchWorkoutSummary], [WatchStartRejected], or a raw event-name
  /// `String` (`'startedOnWatch'`, `'reachabilityChanged'`) as they arrive
  /// from the native side — see docs/40-watch-app-plan.md §3. A no-op stream
  /// (never emits) when [isAvailable] is false.
  Stream<Object> get events {
    if (!isAvailable) return const Stream.empty();
    return _events ??= _eventChannel.receiveBroadcastStream().map(_decodeEvent);
  }

  Object _decodeEvent(dynamic raw) {
    final map = Map<Object?, Object?>.from(raw as Map);
    switch (map['type']) {
      case 'summary':
        return WatchWorkoutSummary.fromJson(Map<Object?, Object?>.from(map['payload'] as Map));
      case 'startRejected':
        return WatchStartRejected(map['sessionClientId'] as String);
      case 'endRequested':
        return WatchEndRequested(map['sessionClientId'] as String);
      default:
        return (map['type'] as String?) ?? 'unknown';
    }
  }

  /// Whether a paired + installed watch app can currently receive a
  /// start/update/end. Best-effort: resolves to false (not an error) if the
  /// channel has no native handler yet.
  Future<bool> isWatchAppAvailable() async {
    if (!isAvailable) return false;
    try {
      return await _channel.invokeMethod<bool>('isWatchAppAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Starts (or re-syncs) the watch's own strength-workout session — see
  /// docs/40-watch-app-plan.md §3 "Indítás". Call alongside, not instead of,
  /// [WorkoutSessionNotifierService.start].
  Future<void> startWorkout({
    required String sessionClientId,
    required String title,
    required DateTime startedAt,
    required WorkoutSessionState state,
  }) async {
    if (!isAvailable) return;
    try {
      await _channel.invokeMethod('startWorkout', {
        'sessionClientId': sessionClientId,
        'title': title,
        'startedAtEpochMs': startedAt.millisecondsSinceEpoch,
        'state': state.toJson(),
      });
    } catch (_) {
      // Best-effort: no paired/installed watch, or the native bridge doesn't
      // exist yet — the phone-side workout is unaffected.
    }
  }

  /// Pushes the latest [state] to the watch's display — call alongside
  /// [WorkoutSessionNotifierService.update] after each set/rest change.
  Future<void> updateState({
    required String sessionClientId,
    required WorkoutSessionState state,
  }) async {
    if (!isAvailable) return;
    try {
      await _channel.invokeMethod('updateState', {
        'sessionClientId': sessionClientId,
        'state': state.toJson(),
      });
    } catch (_) {
      // Best-effort, see class doc.
    }
  }

  /// Tells the watch to close its session — call alongside
  /// [WorkoutSessionNotifierService.end]. The watch answers asynchronously
  /// with a [WatchWorkoutSummary] on [events], not as this call's return
  /// value: docs/40-watch-app-plan.md §3 "Lezárás" — the watch may be
  /// unreachable right now and only answer once it reconnects.
  Future<void> endWorkout(String sessionClientId) async {
    if (!isAvailable) return;
    try {
      await _channel.invokeMethod('endWorkout', {'sessionClientId': sessionClientId});
    } catch (_) {
      // Best-effort, see class doc.
    }
  }
}

final watchWorkoutServiceProvider = Provider<WatchWorkoutService>((ref) {
  return WatchWorkoutService();
});
