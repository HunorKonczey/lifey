import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/my_trainers/data/my_trainers_repository.dart';

/// Records every request and replies with canned JSON — the same fake
/// adapter shape used across this codebase's Dio tests (no mocking package).
class _FakeAdapter implements HttpClientAdapter {
  final List<String> methods = [];
  final List<String> paths = [];
  Object body = [];
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
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  late Dio dio;
  late _FakeAdapter adapter;
  late MyTrainersRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _FakeAdapter();
    dio.httpClientAdapter = adapter;
    repo = MyTrainersRepository(dio);
  });

  test('fetchActiveTrainers GETs /my-trainers and parses each trainer', () async {
    adapter.body = [
      {
        'trainerId': 1,
        'trainerEmail': 'trainer@example.com',
        'activeSince': '2026-06-01T10:00:00Z',
      },
    ];

    final trainers = await repo.fetchActiveTrainers();

    expect(adapter.methods, ['GET']);
    expect(adapter.paths, ['/my-trainers']);
    expect(trainers, hasLength(1));
    expect(trainers.single.trainerId, 1);
    expect(trainers.single.trainerEmail, 'trainer@example.com');
    expect(trainers.single.activeSince, DateTime.parse('2026-06-01T10:00:00Z'));
  });

  test('fetchActiveTrainers returns an empty list when there are none', () async {
    adapter.body = [];

    final trainers = await repo.fetchActiveTrainers();

    expect(trainers, isEmpty);
  });

  test('leave DELETEs /my-trainers/{trainerId}', () async {
    adapter.statusCode = 204;
    adapter.body = '';

    await repo.leave(42);

    expect(adapter.methods, ['DELETE']);
    expect(adapter.paths, ['/my-trainers/42']);
  });
}
