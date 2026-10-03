import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/progress_photos/data/progress_photo_repository.dart';
import 'package:lifey/features/progress_photos/domain/progress_photo.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers each request from a queue and records what was asked.
class _ScriptedAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final _responses = <Object>[]; // ResponseBody or DioException

  void enqueue(Object response) => _responses.add(response);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final next = _responses.removeAt(0);
    if (next is DioException) throw next;
    return next as ResponseBody;
  }
}

ResponseBody _bytes(List<int> data, {int status = 200, String? etag}) => ResponseBody.fromBytes(
      data,
      status,
      headers: {if (etag != null) 'etag': [etag]},
    );

ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Map<String, dynamic> _photoJson(int id, {String takenOn = '2026-06-18', String pose = 'FRONT', String? note}) => {
      'id': id,
      'takenOn': takenOn,
      'pose': pose,
      'note': note,
      'createdAt': '2026-06-18T08:00:00Z',
      'updatedAt': '2026-06-18T08:00:00Z',
    };

void main() {
  late Directory tmp;
  late _ScriptedAdapter adapter;
  late ProgressPhotoRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('progress_photo_test');
    adapter = _ScriptedAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
    repo = ProgressPhotoRepository(dio, cacheRoot: () async => tmp);
  });

  tearDown(() async {
    try {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } on FileSystemException {
      // Windows keeps the upload fixture locked while Dio's MultipartFile
      // holds it open; it is a temp directory, so leaving it is harmless.
    }
  });

  test('list parses the metadata and falls back to OTHER for an unknown pose', () async {
    adapter.enqueue(_json([_photoJson(1, note: 'week 1'), _photoJson(2, pose: 'DIAGONAL')]));

    final photos = await repo.list();

    expect(photos.map((p) => p.id), [1, 2]);
    expect(photos[0].note, 'week 1');
    expect(photos[0].takenOn, DateTime(2026, 6, 18));
    expect(photos[1].pose, PhotoPose.other);
  });

  test('upload sends a multipart form with date, pose and a trimmed note', () async {
    final file = File('${tmp.path}/shot.jpg')..writeAsBytesSync([1, 2, 3]);
    adapter.enqueue(_json(_photoJson(7, pose: 'SIDE'), status: 201));

    final photo = await repo.upload(file, takenOn: DateTime(2026, 6, 18), pose: PhotoPose.side, note: '  hi  ');

    expect(photo.id, 7);
    final sent = adapter.requests.single;
    expect(sent.method, 'POST');
    expect(sent.path, '/progress-photos');
    final form = sent.data as FormData;
    final fields = {for (final f in form.fields) f.key: f.value};
    expect(fields, {'takenOn': '2026-06-18', 'pose': 'SIDE', 'note': 'hi'});
    expect(form.files.single.key, 'file');
  });

  test('upload leaves the note out when blank', () async {
    final file = File('${tmp.path}/shot.jpg')..writeAsBytesSync([1]);
    adapter.enqueue(_json(_photoJson(7), status: 201));

    await repo.upload(file, takenOn: DateTime(2026, 6, 18), pose: PhotoPose.front, note: '   ');

    final fields = {for (final f in (adapter.requests.single.data as FormData).fields) f.key: f.value};
    expect(fields.containsKey('note'), isFalse);
  });

  test('update PATCHes the full metadata, a null note included', () async {
    adapter.enqueue(_json(_photoJson(3, pose: 'BACK')));

    await repo.update(3, takenOn: DateTime(2026, 5, 1), pose: PhotoPose.back);

    final sent = adapter.requests.single;
    expect(sent.method, 'PATCH');
    expect(sent.path, '/progress-photos/3');
    expect(sent.data, {'takenOn': '2026-05-01', 'pose': 'BACK', 'note': null});
  });

  test('a thumbnail is cached with its ETag and revalidated; a 304 serves the cached bytes', () async {
    adapter.enqueue(_bytes([1, 2, 3], etag: '"111"'));
    expect(await repo.fetchThumbnail(5), [1, 2, 3]);

    adapter.enqueue(_bytes(const [], status: 304));
    expect(await repo.fetchThumbnail(5), [1, 2, 3]);

    expect(adapter.requests[0].headers.containsKey('If-None-Match'), isFalse);
    expect(adapter.requests[1].headers['If-None-Match'], '"111"');
    expect(adapter.requests[1].path, '/progress-photos/5/thumbnail');
  });

  test('thumbnail and full image are cached independently', () async {
    adapter.enqueue(_bytes([1], etag: '"t"'));
    adapter.enqueue(_bytes([9, 9], etag: '"f"'));

    expect(await repo.fetchThumbnail(5), [1]);
    expect(await repo.fetchImage(5), [9, 9]);
    // The full image fetch did not reuse the thumbnail's validator.
    expect(adapter.requests[1].headers.containsKey('If-None-Match'), isFalse);
    expect(adapter.requests[1].path, '/progress-photos/5/image');
  });

  test('offline: the cached copy is served, and with no cache the result is null', () async {
    adapter.enqueue(_bytes([4, 4], etag: '"e"'));
    await repo.fetchThumbnail(6);

    adapter.enqueue(DioException.connectionError(requestOptions: RequestOptions(path: '/x'), reason: 'offline'));
    expect(await repo.fetchThumbnail(6), [4, 4]);

    adapter.enqueue(DioException.connectionError(requestOptions: RequestOptions(path: '/x'), reason: 'offline'));
    expect(await repo.fetchThumbnail(99), isNull);
  });

  test('a 404 clears the cache entry and returns null', () async {
    adapter.enqueue(_bytes([1], etag: '"e"'));
    await repo.fetchThumbnail(8);
    adapter.enqueue(_bytes(const [], status: 404));

    expect(await repo.fetchThumbnail(8), isNull);

    adapter.enqueue(_bytes([2], etag: '"e2"'));
    await repo.fetchThumbnail(8);
    // The stale validator is gone, so no If-None-Match is sent.
    expect(adapter.requests.last.headers.containsKey('If-None-Match'), isFalse);
  });

  test('delete calls the server and removes both cached variants', () async {
    adapter.enqueue(_bytes([1], etag: '"t"'));
    adapter.enqueue(_bytes([2], etag: '"f"'));
    await repo.fetchThumbnail(4);
    await repo.fetchImage(4);
    adapter.enqueue(_bytes(const [], status: 204));

    await repo.delete(4);

    expect(adapter.requests.last.method, 'DELETE');
    final cached = Directory('${tmp.path}/progress_photos').listSync();
    expect(cached, isEmpty);
  });

  test('clearCache wipes every file and every ETag (logout)', () async {
    adapter.enqueue(_bytes([1], etag: '"t"'));
    await repo.fetchThumbnail(1);

    await repo.clearCache();

    expect(Directory('${tmp.path}/progress_photos').existsSync(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('progress_photo_etag_')), isEmpty);
  });
}
