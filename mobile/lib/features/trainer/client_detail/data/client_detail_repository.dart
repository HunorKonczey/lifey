import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../domain/client_data.dart';

/// Read-only access to one client's data, for the trainer viewing it
/// (docs/chat/41-trainer-mobile-v2-plan.md T2).
///
/// Online-only, like the client list: nothing here is cached to disk. Every
/// call is guarded server-side by an active trainer-client relationship, so a
/// revoked trainer gets a 403 rather than a stale local copy.
class ClientDetailRepository {
  ClientDetailRepository(this._dio);

  final Dio _dio;

  /// `yyyy-MM-dd`, which is what the `from`/`to`/`date` query params take.
  /// Built by hand rather than with intl: this is a wire format, and a
  /// locale-aware formatter would eventually produce something else.
  static String formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<ClientStatistics> fetchStatistics(
    int clientId,
    ClientStatisticsPeriod period,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.trainerClientStatistics(clientId, period.apiValue),
    );
    return ClientStatistics.fromJson(response.data ?? const {});
  }

  Future<List<ClientStepDay>> fetchSteps(
    int clientId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.trainerClientSteps(clientId),
      queryParameters: _dateRange(from, to),
    );
    return (response.data ?? [])
        .map((json) => ClientStepDay.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<ClientWeightEntry>> fetchWeights(
    int clientId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.trainerClientWeights(clientId),
      queryParameters: _dateRange(from, to),
    );
    return (response.data ?? [])
        .map((json) => ClientWeightEntry.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Always bounded to one day. `/meals` returns an unbounded list otherwise,
  /// and the nutrition tab reads a single day at a time anyway — which is why
  /// the plan's §5.1 paging item never became necessary for this endpoint.
  Future<List<ClientMeal>> fetchMealsForDay(int clientId, DateTime day) async {
    final response = await _dio.get<List<dynamic>>(
      ApiEndpoints.trainerClientMeals(clientId),
      queryParameters: _dateRange(day, day),
    );
    return (response.data ?? [])
        .map((json) => ClientMeal.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<ClientNutritionGoals> fetchNutritionGoals(int clientId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.trainerClientNutritionGoals(clientId),
    );
    return ClientNutritionGoals.fromJson(response.data ?? const {});
  }

  Map<String, String> _dateRange(DateTime? from, DateTime? to) => {
        if (from != null) 'from': formatDate(from),
        if (to != null) 'to': formatDate(to),
      };
}

final clientDetailRepositoryProvider = Provider<ClientDetailRepository>((ref) {
  return ClientDetailRepository(ref.watch(dioClientProvider));
});
