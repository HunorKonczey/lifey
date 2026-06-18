import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/food.dart';

/// REST access to the `/foods` endpoints.
class FoodRepository {
  FoodRepository(this._dio);

  final Dio _dio;

  Future<List<Food>> fetchAll() async {
    final response = await _dio.get<List<dynamic>>('/foods');
    return (response.data ?? const [])
        .map((e) => Food.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Food> create({
    required String name,
    required double calories,
    required double protein,
    double? carbs,
    double? fat,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>('/foods', data: {
      'name': name,
      'caloriesPer100g': calories,
      'proteinPer100g': protein,
      'carbsPer100g': carbs,
      'fatPer100g': fat,
    });
    return Food.fromJson(response.data!);
  }

  Future<Food> update(
    int id, {
    required String name,
    required double calories,
    required double protein,
    double? carbs,
    double? fat,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>('/foods/$id', data: {
      'name': name,
      'caloriesPer100g': calories,
      'proteinPer100g': protein,
      'carbsPer100g': carbs,
      'fatPer100g': fat,
    });
    return Food.fromJson(response.data!);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/foods/$id');
  }
}

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return FoodRepository(ref.watch(dioClientProvider));
});
