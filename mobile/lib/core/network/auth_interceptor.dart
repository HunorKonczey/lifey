import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Attaches the stored access token to outgoing requests and, on a 401,
/// rotates it via the refresh token (backend access tokens are short-lived,
/// 15 minutes) before retrying the original request once.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required Dio refreshDio,
    required Dio mainDio,
    required void Function() onSessionExpired,
  })  : _tokenStorage = tokenStorage,
        _refreshDio = refreshDio,
        _mainDio = mainDio,
        _onSessionExpired = onSessionExpired;

  final TokenStorage _tokenStorage;
  final Dio _refreshDio;
  final Dio _mainDio;
  final void Function() _onSessionExpired;

  Future<void>? _refreshing;

  static const _publicPaths = ['/auth/register', '/auth/login', '/auth/refresh'];

  bool _isPublic(String path) => _publicPaths.any(path.endsWith);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isPublic(options.path)) {
      final token = await _tokenStorage.readAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    // Sent on every request (including register/login) so the backend can
    // keep the user's stored UTC offset current — see the day-boundary bug
    // where the server's own zone was used instead of the user's.
    options.headers['X-Utc-Offset-Minutes'] = DateTime.now().timeZoneOffset.inMinutes.toString();
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final alreadyRetried = err.requestOptions.extra['retried'] == true;
    if (err.response?.statusCode != 401 || _isPublic(err.requestOptions.path) || alreadyRetried) {
      handler.next(err);
      return;
    }

    // Captured before the refresh/retry attempt, which may itself replace
    // the stored token — this is what the *failing* request was sent with.
    final requestToken = _bearerToken(err.requestOptions.headers['Authorization'] as String?);

    try {
      // Concurrent 401s share one in-flight refresh instead of each rotating
      // the (single-use) refresh token themselves.
      await (_refreshing ??= _refresh());
      final token = await _tokenStorage.readAccessToken();
      final retryOptions = err.requestOptions
        ..extra = {...err.requestOptions.extra, 'retried': true}
        ..headers = {...err.requestOptions.headers, 'Authorization': 'Bearer $token'};
      final response = await _mainDio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } catch (_) {
      // A request that started before the user was signed in (e.g. a
      // resume-triggered background sync fired by the OS UI overlay during
      // Google sign-in) can still land here *after* a fresh login has
      // already stored a new, valid token. If storage has moved on to a
      // different token than the one this stale request failed with, a
      // newer session is already active — don't tear it down over it.
      final currentToken = await _tokenStorage.readAccessToken();
      if (currentToken == null || currentToken == requestToken) {
        await _tokenStorage.clear();
        _onSessionExpired();
      }
      handler.next(err);
    } finally {
      _refreshing = null;
    }
  }

  String? _bearerToken(String? header) {
    const prefix = 'Bearer ';
    if (header == null || !header.startsWith(prefix)) return null;
    return header.substring(prefix.length);
  }

  Future<void> _refresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) throw StateError('No refresh token stored');
    // _refreshDio has no interceptors (see dio_client.dart), so the offset
    // header has to be attached here rather than relying on onRequest above —
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
