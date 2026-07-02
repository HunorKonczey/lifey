import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../domain/auth_tokens.dart';

/// REST access to the `/auth` endpoints.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<void> register({required String email, required String password}) async {
    await _dio.post('/auth/register', data: {'email': email, 'password': password});
  }

  Future<AuthTokens> login({required String email, required String password}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthTokens.fromJson(response.data!);
  }

  Future<AuthTokens> loginWithGoogle(String idToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/social/google',
      data: {'idToken': idToken},
    );
    return AuthTokens.fromJson(response.data!);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
  }

  Future<void> logoutAll() async {
    await _dio.post('/auth/logout-all');
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _dio.post(
      '/auth/reset-password',
      data: {'email': email, 'code': code, 'newPassword': newPassword},
    );
  }

  Future<AuthTokens> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/change-password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
    return AuthTokens.fromJson(response.data!);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioClientProvider));
});
