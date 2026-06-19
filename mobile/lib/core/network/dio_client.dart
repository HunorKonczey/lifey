import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_storage.dart';
import 'api_config.dart';
import 'auth_interceptor.dart';
import 'session_events.dart';

/// Provides the configured Dio HTTP client pointed at the Lifey backend.
/// Attaches the stored access token to every request and transparently
/// rotates it via the refresh token on a 401.
final dioClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // Bare client with no interceptors, used only for the refresh call itself
  // so a failed refresh can't recursively trigger another refresh.
  final refreshDio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(AuthInterceptor(
    tokenStorage: ref.watch(tokenStorageProvider),
    refreshDio: refreshDio,
    mainDio: dio,
    onSessionExpired: () => ref.read(sessionExpiredProvider.notifier).notify(),
  ));

  return dio;
});
