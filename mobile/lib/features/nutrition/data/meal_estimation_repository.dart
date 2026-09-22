import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/meal_estimate.dart';

/// Online-only AI estimate of a meal photo (`POST /meals/estimate`,
/// docs/23-ai-calorie-estimation-plan.md). Like [BarcodeLookupRepository], it
/// never touches the local drift cache or the outbox — the result is a
/// suggestion the user edits; saving goes through the normal meal flow.
class MealEstimationRepository {
  MealEstimationRepository(this._dio);

  final Dio _dio;

  /// The model call takes seconds, not milliseconds, and the backend allows
  /// it up to a minute — the client-wide 10 s receive timeout would cut off
  /// answers that are on their way.
  static const receiveTimeout = Duration(seconds: 75);

  Future<MealEstimate> estimate(String imagePath) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.mealEstimate,
      data: FormData.fromMap({
        'image': await MultipartFile.fromFile(imagePath),
      }),
      options: Options(receiveTimeout: receiveTimeout),
    );
    return MealEstimate.fromJson(response.data!);
  }
}

final mealEstimationRepositoryProvider = Provider<MealEstimationRepository>((ref) {
  return MealEstimationRepository(ref.watch(dioClientProvider));
});
