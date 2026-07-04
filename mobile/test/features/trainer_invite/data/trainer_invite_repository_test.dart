import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/trainer_invite/data/trainer_invite_repository.dart';

/// Records every request and replies with canned JSON, mirroring the fake
/// adapter used by `food_update_http_method_test.dart` — no mocking package
/// is used in this codebase for Dio.
class _FakeAdapter implements HttpClientAdapter {
  final List<String> methods = [];
  final List<String> paths = [];
  final List<Object?> bodies = [];
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
    bodies.add(options.data);
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
  late TrainerInviteRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _FakeAdapter();
    dio.httpClientAdapter = adapter;
    repo = TrainerInviteRepository(dio);
  });

  test('fetchPending GETs /trainer-invites/pending and parses each invite', () async {
    adapter.body = [
      {
        'id': 1,
        'trainerEmail': 'trainer@example.com',
        'invitedAt': '2026-07-03T10:00:00Z',
        'expiresAt': '2026-07-04T10:00:00Z',
      },
    ];

    final invites = await repo.fetchPending();

    expect(adapter.methods, ['GET']);
    expect(adapter.paths, ['/trainer-invites/pending']);
    expect(invites, hasLength(1));
    expect(invites.single.id, 1);
    expect(invites.single.trainerEmail, 'trainer@example.com');
    expect(invites.single.expiresAt, DateTime.parse('2026-07-04T10:00:00Z'));
  });

  test('fetchPending returns an empty list when there are no pending invites', () async {
    adapter.body = [];

    final invites = await repo.fetchPending();

    expect(invites, isEmpty);
  });

  test('respond POSTs {accept} to /trainer-invites/{id}/respond', () async {
    adapter.statusCode = 204;
    adapter.body = '';

    await repo.respond(42, accept: true);

    expect(adapter.methods, ['POST']);
    expect(adapter.paths, ['/trainer-invites/42/respond']);
    expect(adapter.bodies.single, {'accept': true});
  });

  test('respond sends accept: false when declining', () async {
    adapter.statusCode = 204;
    adapter.body = '';

    await repo.respond(7, accept: false);

    expect(adapter.bodies.single, {'accept': false});
  });
}
