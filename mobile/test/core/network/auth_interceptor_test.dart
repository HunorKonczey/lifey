import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/network/auth_interceptor.dart';
import 'package:lifey/core/network/token_refresher.dart';
import 'package:lifey/core/storage/token_storage.dart';

/// What a 401 does to the session. Two things must not happen: signing the user out because the refresh
/// could not even be tried (no connection, a 5xx while the API restarts), and answering a request with its
/// stale 401 when the retry produced its own, real, answer.
class _MemoryTokenStorage extends TokenStorage {
  _MemoryTokenStorage({String? access, String? refresh})
      : _access = access,
        _refresh = refresh,
        super(const FlutterSecureStorage());

  String? _access;
  String? _refresh;

  @override
  Future<String?> readAccessToken() async => _access;

  @override
  Future<String?> readRefreshToken() async => _refresh;

  @override
  Future<void> save({required String accessToken, required String refreshToken}) async {
    _access = accessToken;
    _refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

/// Answers every request through a scripted function.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return respond(options);
  }
}

ResponseBody _json(int status, Map<String, dynamic> body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  late _MemoryTokenStorage storage;
  late int sessionExpired;
  late Dio api;

  /// [apiAnswers] is called with the 1-based number of the request to the API.
  void build({
    required ResponseBody Function(int attempt) apiAnswers,
    required ResponseBody Function(RequestOptions options) refreshAnswer,
  }) {
    var attempt = 0;
    final refreshDio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = _Adapter(refreshAnswer);
    api = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = _Adapter((_) => apiAnswers(++attempt));
    api.interceptors.add(AuthInterceptor(
      tokenStorage: storage,
      refresher: TokenRefresher(tokenStorage: storage, refreshDio: refreshDio),
      retryDio: () => api,
      onSessionExpired: () => sessionExpired++,
    ));
  }

  setUp(() {
    storage = _MemoryTokenStorage(access: 'expired', refresh: 'R1');
    sessionExpired = 0;
  });

  ResponseBody refreshed(RequestOptions options) => _json(200, {'accessToken': 'fresh', 'refreshToken': 'R2'});

  test('an expired access token is refreshed and the request goes out again', () async {
    build(
      apiAnswers: (attempt) => attempt == 1 ? _json(401, {'message': 'expired'}) : _json(200, {'ok': true}),
      refreshAnswer: refreshed,
    );

    final response = await api.get<Map<String, dynamic>>('/weights');

    expect(response.data, {'ok': true});
    expect(await storage.readAccessToken(), 'fresh');
    expect(sessionExpired, 0);
  });

  test('a refused refresh token ends the session', () async {
    build(
      apiAnswers: (attempt) => _json(401, {'message': 'expired'}),
      refreshAnswer: (options) => _json(401, {'message': 'revoked'}),
    );

    await expectLater(api.get<dynamic>('/weights'), throwsA(isA<DioException>()));

    expect(sessionExpired, 1);
    expect(await storage.readAccessToken(), isNull);
  });

  test('a refresh that could not reach the server does not sign the user out', () async {
    build(
      apiAnswers: (attempt) => _json(401, {'message': 'expired'}),
      refreshAnswer: (options) => throw DioException.connectionError(requestOptions: options, reason: 'offline'),
    );

    await expectLater(api.get<dynamic>('/weights'), throwsA(isA<DioException>()));

    expect(sessionExpired, 0);
    expect(await storage.readAccessToken(), 'expired');
    expect(await storage.readRefreshToken(), 'R1');
  });

  test('a 502 from the gateway during the refresh does not sign the user out either', () async {
    build(
      apiAnswers: (attempt) => _json(401, {'message': 'expired'}),
      refreshAnswer: (options) => _json(502, {'message': 'bad gateway'}),
    );

    await expectLater(api.get<dynamic>('/weights'), throwsA(isA<DioException>()));

    expect(sessionExpired, 0);
    expect(await storage.readRefreshToken(), 'R1');
  });

  test('when the retried request fails on its own, the caller sees that answer, not the stale 401', () async {
    build(
      apiAnswers: (attempt) =>
          attempt == 1 ? _json(401, {'message': 'expired'}) : _json(400, {'message': 'weight must be positive'}),
      refreshAnswer: refreshed,
    );

    DioException? error;
    try {
      await api.get<dynamic>('/weights');
    } on DioException catch (e) {
      error = e;
    }

    expect(error?.response?.statusCode, 400);
    expect(sessionExpired, 0);
    expect(await storage.readAccessToken(), 'fresh');
  });
}
