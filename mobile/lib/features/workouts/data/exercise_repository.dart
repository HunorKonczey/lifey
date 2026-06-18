import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/exercise.dart';

/// REST access to the `/exercises` master list (read + manage).
class ExerciseRepository {
  ExerciseRepository(this._dio);

  final Dio _dio;

  Future<List<Exercise>> fetchAll() async {
    final response = await _dio.get<List<dynamic>>('/exercises');
    return (response.data ?? const [])
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Exercise> create(String name) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/exercises',
      data: {'name': name},
    );
    return Exercise.fromJson(response.data!);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/exercises/$id');
  }
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepository(ref.watch(dioClientProvider));
});
