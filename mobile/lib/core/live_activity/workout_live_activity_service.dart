import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mirrors the Swift `WorkoutActivityAttributes.ContentState` in
/// docs/24-ios-widget-live-activity-plan.md — the mutable part of a
/// running workout's Live Activity.
class LiveActivityContentState {
  const LiveActivityContentState({
    required this.exerciseName,
    required this.setsDone,
    this.setsTotal,
    required this.totalSetsDone,
    this.lastSetAtEpochMs,
  });

  /// Current (last touched) exercise name; pass a pre-localized fallback
  /// (e.g. "Gyakorlat") for the empty-block case rather than an empty string.
  final String exerciseName;
  final int setsDone;
  final int? setsTotal;
  final int totalSetsDone;
  final int? lastSetAtEpochMs;

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'setsDone': setsDone,
        'setsTotal': setsTotal,
        'totalSetsDone': totalSetsDone,
        'lastSetAtEpochMs': lastSetAtEpochMs,
      };
}

/// Thin wrapper over the hand-rolled `lifey/live_activity` MethodChannel
/// (see docs/24-ios-widget-live-activity-plan.md, "Hand-rolled MethodChannel
/// for the Live Activity"). No `live_activities` package — ActivityKit
/// start/update/end lives in ~80 lines of Swift behind this channel.
///
/// No-ops on non-iOS and (native-side) below iOS 16.1 / when Live Activities
/// are disabled in Settings.
class WorkoutLiveActivityService {
  WorkoutLiveActivityService({MethodChannel? channel, bool? isAvailable})
      : _channel = channel ?? const MethodChannel('lifey/live_activity'),
        isAvailable = isAvailable ?? Platform.isIOS;

  final MethodChannel _channel;

  /// Defaults to [Platform.isIOS]; overridable in the constructor so tests
  /// can exercise the channel calls on non-iOS test hosts.
  final bool isAvailable;

  /// Starts a new Live Activity for [sessionClientId]. Returns the native
  /// activity id, or null when unavailable/no-op.
  Future<String?> start({
    required String sessionClientId,
    required String title,
    required DateTime startedAt,
    required LiveActivityContentState state,
  }) async {
    if (!isAvailable) return null;
    return _channel.invokeMethod<String>('start', {
      'sessionClientId': sessionClientId,
      'title': title,
      'startedAtEpochMs': startedAt.millisecondsSinceEpoch,
      'state': state.toJson(),
    });
  }

  /// Updates the running activity matching [sessionClientId] with a new
  /// content state. No-ops (native side) if none is found.
  Future<void> update({
    required String sessionClientId,
    required LiveActivityContentState state,
  }) async {
    if (!isAvailable) return;
    await _channel.invokeMethod('update', {
      'sessionClientId': sessionClientId,
      'state': state.toJson(),
    });
  }

  /// Ends the current workout's Live Activity immediately.
  Future<void> end() async {
    if (!isAvailable) return;
    await _channel.invokeMethod('end');
  }

  /// Safety sweep: ends every orphaned Live Activity. Called once on app
  /// start when no in-progress session was found (see
  /// [workoutResumePromptProvider]).
  Future<void> endAll() async {
    if (!isAvailable) return;
    await _channel.invokeMethod('endAll');
  }
}

final workoutLiveActivityServiceProvider = Provider<WorkoutLiveActivityService>((ref) {
  return WorkoutLiveActivityService();
});
