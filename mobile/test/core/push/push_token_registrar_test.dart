import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/push/push_token_registrar.dart';
import 'package:lifey/core/push/push_token_source.dart';

/// Records every request and replies with canned JSON — the same fake
/// adapter shape used across this codebase's Dio tests (no mocking package).
class _FakeAdapter implements HttpClientAdapter {
  final List<String> methods = [];
  final List<String> paths = [];
  final List<Object?> bodies = [];
  int statusCode = 200;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    methods.add(options.method);
    paths.add(options.path);
    bodies.add(options.data);
    if (statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: statusCode),
      );
    }
    return ResponseBody.fromString(
      jsonEncode(null),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _FakeTokenSource implements PushTokenSource {
  @override
  final String platform = 'IOS';

  String? tokenToReturn;
  int getTokenCallCount = 0;

  final _rotationController = StreamController<String>.broadcast();

  @override
  Future<String?> getToken() async {
    getTokenCallCount++;
    return tokenToReturn;
  }

  @override
  Stream<String> get onTokenRefreshed => _rotationController.stream;

  void rotateTo(String token) => _rotationController.add(token);
}

void main() {
  late Dio dio;
  late _FakeAdapter adapter;
  late _FakeTokenSource source;
  late PushTokenRegistrar registrar;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _FakeAdapter();
    dio.httpClientAdapter = adapter;
    source = _FakeTokenSource()..tokenToReturn = 'token-1';
    registrar = PushTokenRegistrar(dio, source);
  });

  group('register', () {
    test('PUTs the token and platform to /push/devices', () async {
      await registrar.register();

      expect(adapter.methods, ['PUT']);
      expect(adapter.paths, ['/push/devices']);
      expect(adapter.bodies.single, {'platform': 'IOS', 'token': 'token-1'});
    });

    test('does nothing when the token source returns null (permission denied)', () async {
      source.tokenToReturn = null;

      await registrar.register();

      expect(adapter.methods, isEmpty);
    });

    test('does not throw when the PUT fails', () async {
      adapter.statusCode = 500;

      await expectLater(registrar.register(), completes);
    });

    test('re-PUTs when the source reports a rotated token', () async {
      await registrar.register();
      source.rotateTo('token-2');
      await pumpEventQueue();

      expect(adapter.methods, ['PUT', 'PUT']);
      expect(adapter.bodies.last, {'platform': 'IOS', 'token': 'token-2'});
    });

    test('registering twice does not attach a second rotation listener', () async {
      await registrar.register();
      await registrar.register();
      source.rotateTo('token-2');
      await pumpEventQueue();

      // 2 initial PUTs (one per register() call) + 1 for the single rotation.
      expect(adapter.methods, ['PUT', 'PUT', 'PUT']);
    });
  });

  group('unregister', () {
    test('DELETEs the last successfully registered token', () async {
      await registrar.register();
      await registrar.unregister();

      expect(adapter.methods, ['PUT', 'DELETE']);
      expect(adapter.paths, ['/push/devices', '/push/devices/token-1']);
    });

    test('does nothing when nothing was ever successfully registered', () async {
      source.tokenToReturn = null;
      await registrar.register();
      await registrar.unregister();

      expect(adapter.methods, isEmpty);
    });

    test('does not throw when the DELETE fails', () async {
      await registrar.register();
      adapter.statusCode = 500;

      await expectLater(registrar.unregister(), completes);
    });

    test('stops listening for rotations after unregister', () async {
      await registrar.register();
      await registrar.unregister();
      source.rotateTo('token-2');
      await pumpEventQueue();

      // Only the initial PUT and the DELETE — the post-unregister rotation
      // must not trigger another PUT.
      expect(adapter.methods, ['PUT', 'DELETE']);
    });

    test('a second unregister without a re-register is a no-op', () async {
      await registrar.register();
      await registrar.unregister();
      await registrar.unregister();

      expect(adapter.methods, ['PUT', 'DELETE']);
    });
  });
}
