import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/workout_template.dart';

/// REST access to the `/workout-templates` endpoints (list, create, update, delete).
class WorkoutTemplateRepository {
  WorkoutTemplateRepository(this._dio);

  final Dio _dio;

  Future<List<WorkoutTemplate>> fetchAll() async {
    final response = await _dio.get<List<dynamic>>('/workout-templates');
    return (response.data ?? const [])
        .map((e) => WorkoutTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WorkoutTemplate> create({
    required String name,
    required List<int> exerciseIds,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/workout-templates',
      data: {'name': name, 'exerciseIds': exerciseIds},
    );
    return WorkoutTemplate.fromJson(response.data!);
  }

  Future<WorkoutTemplate> update({
    required int id,
    required String name,
    required List<int> exerciseIds,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/workout-templates/$id',
      data: {'name': name, 'exerciseIds': exerciseIds},
    );
    return WorkoutTemplate.fromJson(response.data!);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/workout-templates/$id');
  }
}

final workoutTemplateRepositoryProvider =
    Provider<WorkoutTemplateRepository>((ref) {
  return WorkoutTemplateRepository(ref.watch(dioClientProvider));
});
