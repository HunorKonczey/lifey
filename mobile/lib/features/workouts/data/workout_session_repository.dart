import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/workout_session.dart';

/// One set to record when logging a session (request side).
class ExerciseSetInput {
  const ExerciseSetInput({
    required this.exerciseId,
    required this.reps,
    required this.weight,
  });

  final int exerciseId;
  final int reps;
  final double weight;
}

/// REST access to the `/workout-sessions` endpoints (list + create).
class WorkoutSessionRepository {
  WorkoutSessionRepository(this._dio);

  final Dio _dio;

  Future<List<WorkoutSession>> fetchAll() async {
    final response = await _dio.get<List<dynamic>>('/workout-sessions');
    return (response.data ?? const [])
        .map((e) => WorkoutSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WorkoutSession> create({
    required DateTime startedAt,
    DateTime? finishedAt,
    required List<ExerciseSetInput> sets,
  }) async {
    // Backend uses Instant (UTC) — send ISO-8601 with a zone.
    final response = await _dio.post<Map<String, dynamic>>(
      '/workout-sessions',
      data: {
        'startedAt': startedAt.toUtc().toIso8601String(),
        if (finishedAt != null) 'finishedAt': finishedAt.toUtc().toIso8601String(),
        'sets': sets
            .map((s) => {
                  'exerciseId': s.exerciseId,
                  'reps': s.reps,
                  'weight': s.weight,
                })
            .toList(),
      },
    );
    return WorkoutSession.fromJson(response.data!);
  }

  Future<WorkoutSession> update(
    int id, {
    required DateTime startedAt,
    DateTime? finishedAt,
    required List<ExerciseSetInput> sets,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/workout-sessions/$id',
      data: {
        'startedAt': startedAt.toUtc().toIso8601String(),
        if (finishedAt != null) 'finishedAt': finishedAt.toUtc().toIso8601String(),
        'sets': sets
            .map((s) => {
                  'exerciseId': s.exerciseId,
                  'reps': s.reps,
                  'weight': s.weight,
                })
            .toList(),
      },
    );
    return WorkoutSession.fromJson(response.data!);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/workout-sessions/$id');
  }
}

final workoutSessionRepositoryProvider =
    Provider<WorkoutSessionRepository>((ref) {
  return WorkoutSessionRepository(ref.watch(dioClientProvider));
});
