import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

/// The trainer's own preferences — today just whether the weekly digest email
/// goes out (docs/33-weekly-trainer-report-plan.md).
///
/// Deliberately separate from `/settings`, which is the client-side settings
/// round-trip: this one is trainer-only, and the backend keeps the same split.
class TrainerPreferences {
  const TrainerPreferences({this.weeklyReportEmailEnabled = true});

  final bool weeklyReportEmailEnabled;

  factory TrainerPreferences.fromJson(Map<String, dynamic> json) {
    return TrainerPreferences(
      weeklyReportEmailEnabled: json['weeklyReportEmailEnabled'] as bool? ?? true,
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

  Future<TrainerPreferences> setWeeklyReportEmailEnabled(bool enabled) async {
    final response = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.trainerPreferences,
      data: {'weeklyReportEmailEnabled': enabled},
    );
    return TrainerPreferences.fromJson(response.data ?? const {});
  }
}

final trainerPreferencesRepositoryProvider =
    Provider<TrainerPreferencesRepository>((ref) {
  return TrainerPreferencesRepository(ref.watch(dioClientProvider));
});

/// The trainer's preferences, with the one toggle that exists.
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
  Future<void> setWeeklyReportEmailEnabled(bool enabled) async {
    final previous = state.value;
    try {
      state = AsyncData(
        await ref
            .read(trainerPreferencesRepositoryProvider)
            .setWeeklyReportEmailEnabled(enabled),
      );
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
