import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

/// The trainer's own preferences: whether the weekly digest email goes out
/// (docs/33-weekly-trainer-report-plan.md) and which client pushes they get
/// (docs/85-trainer-push-plan.md).
///
/// Deliberately separate from `/settings`, which is the client-side settings
/// round-trip: this one is trainer-only, and the backend keeps the same split.
class TrainerPreferences {
  const TrainerPreferences({
    this.weeklyReportEmailEnabled = true,
    this.clientMissedWorkoutPushEnabled = true,
    this.clientWeighInPushEnabled = true,
  });

  final bool weeklyReportEmailEnabled;

  /// A push when a client misses a scheduled workout.
  final bool clientMissedWorkoutPushEnabled;

  /// A push when a client logs the first weigh-in of their week.
  final bool clientWeighInPushEnabled;

  factory TrainerPreferences.fromJson(Map<String, dynamic> json) {
    // A missing field is "on", like the backend default (an older server knows only the first switch).
    return TrainerPreferences(
      weeklyReportEmailEnabled: json['weeklyReportEmailEnabled'] as bool? ?? true,
      clientMissedWorkoutPushEnabled: json['clientMissedWorkoutPushEnabled'] as bool? ?? true,
      clientWeighInPushEnabled: json['clientWeighInPushEnabled'] as bool? ?? true,
    );
  }
}

class TrainerPreferencesRepository {
  TrainerPreferencesRepository(this._dio);

  final Dio _dio;

  Future<TrainerPreferences> fetch() async {
    final response =
        await _dio.get<Map<String, dynamic>>(ApiEndpoints.trainerPreferences);
    return TrainerPreferences.fromJson(response.data ?? const {});
  }

  Future<TrainerPreferences> setWeeklyReportEmailEnabled(bool enabled) => _put({'weeklyReportEmailEnabled': enabled});

  Future<TrainerPreferences> setClientMissedWorkoutPushEnabled(bool enabled) =>
      _put({'clientMissedWorkoutPushEnabled': enabled});

  Future<TrainerPreferences> setClientWeighInPushEnabled(bool enabled) => _put({'clientWeighInPushEnabled': enabled});

  /// Sends only the switch that changed: the backend keeps what is absent.
  Future<TrainerPreferences> _put(Map<String, bool> changed) async {
    final response = await _dio.put<Map<String, dynamic>>(ApiEndpoints.trainerPreferences, data: changed);
    return TrainerPreferences.fromJson(response.data ?? const {});
  }
}

final trainerPreferencesRepositoryProvider =
    Provider<TrainerPreferencesRepository>((ref) {
  return TrainerPreferencesRepository(ref.watch(dioClientProvider));
});

/// The trainer's preferences and their toggles.
///
/// No optimistic flip: the switch shows what the server confirmed, because a
/// toggle that springs back after a failed save is worse than one that waits.
class TrainerPreferencesController extends AsyncNotifier<TrainerPreferences> {
  @override
  Future<TrainerPreferences> build() {
    return ref.read(trainerPreferencesRepositoryProvider).fetch();
  }

  /// Throws on failure, after putting the known value back.
  ///
  /// A failed *write* does not make the preference unknown — it is still
  /// whatever it was — so the row keeps showing it rather than collapsing
  /// into an error state and taking the switch with it. The caller reports
  /// the failure.
  Future<void> setWeeklyReportEmailEnabled(bool enabled) =>
      _write((repository) => repository.setWeeklyReportEmailEnabled(enabled));

  Future<void> setClientMissedWorkoutPushEnabled(bool enabled) =>
      _write((repository) => repository.setClientMissedWorkoutPushEnabled(enabled));

  Future<void> setClientWeighInPushEnabled(bool enabled) =>
      _write((repository) => repository.setClientWeighInPushEnabled(enabled));

  Future<void> _write(Future<TrainerPreferences> Function(TrainerPreferencesRepository repository) write) async {
    final previous = state.value;
    try {
      state = AsyncData(await write(ref.read(trainerPreferencesRepositoryProvider)));
    } catch (_) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }
}

final trainerPreferencesControllerProvider =
    AsyncNotifierProvider<TrainerPreferencesController, TrainerPreferences>(
  TrainerPreferencesController.new,
);
