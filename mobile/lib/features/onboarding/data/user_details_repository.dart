import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/user_details.dart';

/// Direct network access to onboarding user details. Unlike most
/// repositories in this app, onboarding happens right after registration
/// (i.e. online) — no offline/outbox involvement here. The initial-weight
/// write during onboarding still goes through WeightRepository, so it lands
/// in the local DB + sync flow like any other weight entry.
class UserDetailsRepository {
  UserDetailsRepository(this._dio);

  final Dio _dio;

  /// Throws a [DioException] with `response?.statusCode == 404` when the
  /// user hasn't completed onboarding yet.
  Future<UserDetails> get() async {
    final response = await _dio.get<Map<String, dynamic>>('/user-details');
    return UserDetails.fromJson(response.data!);
  }

  Future<UserDetails> upsert(UserDetails details) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/user-details',
      data: details.toJson(),
    );
    return UserDetails.fromJson(response.data!);
  }

  /// Stateless — nothing is persisted, safe to call repeatedly while the
  /// wizard is open to preview goals before the user commits to anything.
  Future<SuggestGoalsResult> suggestGoals({
    required Gender gender,
    required DateTime birthDate,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activityLevel,
    required PrimaryGoal primaryGoal,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/user-details/suggest-goals',
      data: {
        'gender': genderToJson(gender),
        'birthDate': formatDateOnly(birthDate),
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activityLevel': activityLevelToJson(activityLevel),
        'primaryGoal': primaryGoalToJson(primaryGoal),
      },
    );
    return SuggestGoalsResult.fromJson(response.data!);
  }
}

final userDetailsRepositoryProvider = Provider<UserDetailsRepository>((ref) {
  return UserDetailsRepository(ref.watch(dioClientProvider));
});

/// The current user's onboarding details, or null (not an error) on a 404 —
/// that's the expected "not onboarded yet" response. Used by the Settings
/// edit screen; [hasUserDetailsProvider] derives from this for the dashboard
/// banner so the two never disagree from separate fetches.
final userDetailsProvider = FutureProvider<UserDetails?>((ref) async {
  try {
    return await ref.watch(userDetailsRepositoryProvider).get();
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return null;
    rethrow;
  }
});

final hasUserDetailsProvider = FutureProvider<bool>((ref) async {
  return (await ref.watch(userDetailsProvider.future)) != null;
});
