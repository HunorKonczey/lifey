import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'token_refresher.dart';

/// Attaches the stored access token to outgoing requests and, on a 401,
/// rotates it via the refresh token (backend access tokens are short-lived,
/// 15 minutes) before retrying the original request once.
///
/// One instance per [Dio], and there are two of them since the chat became its
/// own service. The two things that must NOT be duplicated per instance are
/// handled elsewhere: token rotation is shared through [TokenRefresher], and
/// the retry goes back out through [retryDio] — the very client the request
/// came from, so a chat request is retried against the chat service rather
/// than against whichever `Dio` happened to be wired in here.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required TokenRefresher refresher,
    required Dio Function() retryDio,
    required void Function() onSessionExpired,
  })  : _tokenStorage = tokenStorage,
        _refresher = refresher,
        _retryDio = retryDio,
        _onSessionExpired = onSessionExpired;

  final TokenStorage _tokenStorage;
  final TokenRefresher _refresher;

  /// A callback rather than the instance: the interceptor is built *while* its
  /// own `Dio` is being constructed, so it cannot hold a reference to it yet.
  final Dio Function() _retryDio;

  final void Function() _onSessionExpired;

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
      // Shared across both Dio clients: the refresh token is single-use, so two
      // simultaneous rotations would spend it twice and sign the user out.
      await _refresher.refresh();
      final token = await _tokenStorage.readAccessToken();
      final retryOptions = err.requestOptions
        ..extra = {...err.requestOptions.extra, 'retried': true}
        ..headers = {...err.requestOptions.headers, 'Authorization': 'Bearer $token'};
      final response = await _retryDio().fetch<dynamic>(retryOptions);
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
    }
  }

  String? _bearerToken(String? header) {
    const prefix = 'Bearer ';
    if (header == null || !header.startsWith(prefix)) return null;
    return header.substring(prefix.length);
  }
}
