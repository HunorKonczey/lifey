import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../domain/client_data.dart';
import '../domain/client_workout_session.dart';

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

  /// Replaces all four goals at once — the endpoint is a full overwrite, and
  /// a null field clears that goal rather than leaving it alone.
  ///
  /// The backend pushes the client a notification only when a value actually
  /// changed (docs/32), which is why the editor compares before and after
  /// instead of announcing a notification on every save.
  Future<ClientNutritionGoals> updateNutritionGoals(
    int clientId,
    ClientNutritionGoals goals,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.trainerClientNutritionGoals(clientId),
      data: {
        'dailyCalorieGoal': goals.dailyCalorieGoal?.round(),
        'dailyProteinGoal': goals.dailyProteinGoal?.round(),
        'dailyCarbsGoal': goals.dailyCarbsGoal?.round(),
        'dailyFatGoal': goals.dailyFatGoal?.round(),
      },
    );
    return ClientNutritionGoals.fromJson(response.data ?? const {});
  }

  /// One page of the client's finished sessions, newest first — the order the
  /// backend already sorts by, so no `sort` parameter is sent.
  Future<ClientSessionPage> fetchWorkoutSessions(
    int clientId, {
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.trainerClientWorkoutSessions(clientId),
      queryParameters: {'page': page, 'size': size},
    );
    return ClientSessionPage.fromJson(response.data ?? const {});
  }

  /// Writes (or rewrites) the trainer's comment. Returns the session the
  /// server ended up with, so the caller shows what was actually stored
  /// rather than what it hoped to store — this surface has no optimistic UI
  /// (docs/chat/41 §2.2).
  Future<ClientWorkoutSession> putSessionComment(
    int clientId,
    int sessionId,
    String comment,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      ApiEndpoints.trainerClientSessionComment(clientId, sessionId),
      data: {'comment': comment},
    );
    return ClientWorkoutSession.fromJson(response.data ?? const {});
  }

  Future<ClientWorkoutSession> deleteSessionComment(
    int clientId,
    int sessionId,
  ) async {
    final response = await _dio.delete<Map<String, dynamic>>(
      ApiEndpoints.trainerClientSessionComment(clientId, sessionId),
    );
    return ClientWorkoutSession.fromJson(response.data ?? const {});
  }

  Map<String, String> _dateRange(DateTime? from, DateTime? to) => {
        if (from != null) 'from': formatDate(from),
        if (to != null) 'to': formatDate(to),
      };
}

final clientDetailRepositoryProvider = Provider<ClientDetailRepository>((ref) {
  return ClientDetailRepository(ref.watch(dioClientProvider));
});
