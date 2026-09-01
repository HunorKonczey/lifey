import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_storage.dart';
import 'api_config.dart';
import 'auth_interceptor.dart';
import 'client_config.dart';
import 'gate_rejection_interceptor.dart';
import 'session_events.dart';
import 'token_refresher.dart';

/// Bare client with no interceptors, used only for the refresh call itself so a
/// failed refresh can't recursively trigger another refresh.
///
/// Always points at **lifey-api**, even when the request that hit a 401 came
/// from the chat service: only lifey-api issues tokens
/// (docs/chat/44-chat-service-extraction-plan.md §5.3).
final _refreshDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );
});

/// Shared by every client, because the refresh token is single-use — see
/// [TokenRefresher].
final tokenRefresherProvider = Provider<TokenRefresher>((ref) {
  return TokenRefresher(
    tokenStorage: ref.watch(tokenStorageProvider),
    refreshDio: ref.watch(_refreshDioProvider),
  );
});

Dio _authenticatedDio(Ref ref, String baseUrl) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(AuthInterceptor(
    tokenStorage: ref.watch(tokenStorageProvider),
    refresher: ref.watch(tokenRefresherProvider),
    // Retries go back out through this same client, so a request keeps its own
    // host. Late-bound because `dio` is still being built here.
    retryDio: () => dio,
    onSessionExpired: () => ref.read(sessionExpiredProvider.notifier).notify(),
  ));
  dio.interceptors.add(GateRejectionInterceptor(
    onGateRejection: () => ref.read(gateRejectionProvider.notifier).notify(),
  ));

  return dio;
}

/// The main API client. Everything except the chat goes through this.
final dioClientProvider = Provider<Dio>((ref) => _authenticatedDio(ref, ApiConfig.baseUrl));

/// The chat client.
///
/// Same tokens, same session handling, different host — and the host is decided
/// at **runtime** ([chatBaseUrlProvider]), not compiled in, so moving the chat
/// between services (or moving it back) is a server-side change
/// (docs/chat/44-chat-service-extraction-plan.md §7.1).
///
/// Watching the base URL means this client — and everything built on it,
/// including the SSE stream — is rebuilt when the answer changes. That rebuild
/// is what reconnects the stream to the new host without an app restart.
///
/// **Not everything under `features/chat/` belongs on this client.**
/// `TrainerClientsRepository` calls `/trainer/clients`, which is the main API's,
/// and stays on [dioClientProvider].
final chatDioProvider = Provider<Dio>((ref) {
  return _authenticatedDio(ref, ref.watch(chatBaseUrlProvider));
});
