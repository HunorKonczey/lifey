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
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final alreadyRetried = err.requestOptions.extra['retried'] == true;
    if (err.response?.statusCode != 401 || _isPublic(err.requestOptions.path) || alreadyRetried) {
      handler.next(err);
      return;
    }

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
      await _tokenStorage.clear();
      _onSessionExpired();
      handler.next(err);
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _refresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) throw StateError('No refresh token stored');
    final response = await _refreshDio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final data = response.data!;
    await _tokenStorage.save(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }
}
