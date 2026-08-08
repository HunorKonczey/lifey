import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'dio_client.dart';

/// Rotates the access token, and makes sure that only ever happens once at a
/// time.
///
/// **Why this is its own object.** The refresh token is single-use: the backend
/// hands back a new one and invalidates the old. So two refreshes racing means
/// one of them presents a token that has already been spent, fails, and tears
/// the session down — the user is signed out for no reason.
///
/// That used to be handled inside [AuthInterceptor] with a private in-flight
/// future, which was enough while there was one `Dio`. Since the chat moved to
/// its own service there are two (see [dioClientProvider] and
/// [chatDioProvider]), each with its own interceptor — and two interceptors
/// with a private future each is exactly the race the private future was
/// written to prevent. The coordination therefore has to live where both can
/// share it.
///
/// Refresh always goes to **lifey-api**, whichever service returned the 401:
/// the chat service only ever verifies tokens, it cannot issue one
/// (docs/chat/44-chat-service-extraction-plan.md §5.3).
class TokenRefresher {
  TokenRefresher({required TokenStorage tokenStorage, required Dio refreshDio})
      : _tokenStorage = tokenStorage,
        _refreshDio = refreshDio;

  final TokenStorage _tokenStorage;
  final Dio _refreshDio;

  Future<void>? _inFlight;

  /// Concurrent callers await the same rotation rather than starting their own.
  Future<void> refresh() {
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<void> _refresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) throw StateError('No refresh token stored');
    // _refreshDio has no interceptors (see dio_client.dart), so the offset
    // header has to be attached here rather than relying on AuthInterceptor —
    // this is the main mechanism that keeps existing users' offset current,
    // since refresh fires far more often than login/register.
    final response = await _refreshDio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: Options(headers: {
        'X-Utc-Offset-Minutes': DateTime.now().timeZoneOffset.inMinutes.toString(),
      }),
    );
    final data = response.data!;
    await _tokenStorage.save(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }
}
