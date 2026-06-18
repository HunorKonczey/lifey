import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/dashboard_data.dart';
import '../domain/daily_stats.dart';
import '../domain/recent_workout.dart';

/// Loads the dashboard by combining the daily statistics and recent workouts.
class DashboardRepository {
  DashboardRepository(this._dio);

  final Dio _dio;

  static const _recentWorkoutLimit = 5;

  Future<DashboardData> load() async {
    final responses = await Future.wait([
      _dio.get<Map<String, dynamic>>('/statistics/daily'),
      _dio.get<List<dynamic>>('/workout-sessions'),
    ]);

    final stats = DailyStats.fromJson(responses[0].data as Map<String, dynamic>);

    final sessions = (responses[1].data as List<dynamic>? ?? const [])
        .map((e) => RecentWorkout.fromJson(e as Map<String, dynamic>))
        .take(_recentWorkoutLimit)
        .toList();

    return DashboardData(stats: stats, recentWorkouts: sessions);
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(dioClientProvider));
});
