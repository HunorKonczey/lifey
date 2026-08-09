import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/chat/data/peer_avatar_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One canned reply per call, with every request recorded — the same
/// fake-adapter shape as the other Dio tests here, no mocking package.
class _FakeAdapter implements HttpClientAdapter {
  final List<ResponseBody Function()> replies = [];
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (replies.isEmpty) throw StateError('no canned reply left');
    return replies.removeAt(0)();
  }
}

ResponseBody _bytes(List<int> body, {int status = 200, String? etag}) => ResponseBody.fromBytes(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['image/jpeg'],
        if (etag != null) 'etag': [etag],
      },
    );

void main() {
  const peerId = 42;

  late Directory tempDir;
  late _FakeAdapter adapter;
  late PeerAvatarRepository repo;

  setUp(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('peer_avatar_test');
    // The cache writes into the app documents directory; in a plain unit test
    // that channel isn't there, so point it somewhere real for the test.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async =>
          call.method == 'getApplicationDocumentsDirectory' ? tempDir.path : null,
    );
    SharedPreferences.setMockInitialValues({});

    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
      ..httpClientAdapter = adapter;
    repo = PeerAvatarRepository(dio);
  });

  tearDown(() async {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('serves the peer picture and revalidates the next read with its ETag', () async {
    adapter.replies.add(() => _bytes([1, 2, 3], etag: '"7"'));
    adapter.replies.add(() => _bytes(const [], status: 304));

    expect(await repo.fetch(peerId), Uint8List.fromList([1, 2, 3]));
    // A 304 carries no body — the bytes come back from the on-disk copy.
    expect(await repo.fetch(peerId), Uint8List.fromList([1, 2, 3]));

    expect(adapter.requests.first.path, '/users/$peerId/avatar');
    expect(adapter.requests.first.headers['If-None-Match'], isNull);
    expect(adapter.requests.last.headers['If-None-Match'], '"7"');
  });

  test('a peer with no picture — or one we may no longer see — reads as null', () async {
    adapter.replies.add(() => _bytes(const [], status: 404));

    expect(await repo.fetch(peerId), isNull);
  });

  test('a picture that was cached survives losing the network', () async {
    adapter.replies.add(() => _bytes([9, 9], etag: '"1"'));
    expect(await repo.fetch(peerId), Uint8List.fromList([9, 9]));

    adapter.replies.add(() => throw DioException.connectionError(
          requestOptions: RequestOptions(path: '/users/$peerId/avatar'),
          reason: 'offline',
        ));

    expect(await repo.fetch(peerId), Uint8List.fromList([9, 9]));
  });

  test('a 404 drops the cached copy instead of showing a picture that is gone', () async {
    adapter.replies.add(() => _bytes([5], etag: '"1"'));
    await repo.fetch(peerId);

    adapter.replies.add(() => _bytes(const [], status: 404));
    expect(await repo.fetch(peerId), isNull);

    // Nothing cached and nothing to revalidate: the next read starts over.
    adapter.replies.add(() => _bytes(const [], status: 404));
    await repo.fetch(peerId);
    expect(adapter.requests.last.headers['If-None-Match'], isNull);
  });
}
