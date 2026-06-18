import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/dio_client.dart';
import '../domain/meal.dart';

/// One food + quantity to include when logging a meal (request side).
class MealEntryInput {
  const MealEntryInput({required this.foodId, required this.grams});

  final int foodId;
  final double grams;
}

/// REST access to the `/meals` endpoints.
class MealRepository {
  MealRepository(this._dio);

  final Dio _dio;

  // Backend expects a LocalDateTime, i.e. an ISO string without a zone.
  static final _dateTimeFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

  Future<List<Meal>> fetchAll() async {
    final response = await _dio.get<List<dynamic>>('/meals');
    return (response.data ?? const [])
        .map((e) => Meal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Meal> create({
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>('/meals', data: {
      'dateTime': _dateTimeFormat.format(dateTime),
      'mealType': mealType.apiValue,
      'entries': entries
          .map((e) => {'foodId': e.foodId, 'quantityInGrams': e.grams})
          .toList(),
    });
    return Meal.fromJson(response.data!);
  }

  Future<Meal> update(
    int id, {
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>('/meals/$id', data: {
      'dateTime': _dateTimeFormat.format(dateTime),
      'mealType': mealType.apiValue,
      'entries': entries
          .map((e) => {'foodId': e.foodId, 'quantityInGrams': e.grams})
          .toList(),
    });
    return Meal.fromJson(response.data!);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/meals/$id');
  }
}

final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return MealRepository(ref.watch(dioClientProvider));
});
