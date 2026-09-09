import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/trainer/clients/data/trainer_clients_repository.dart';

/// Records every request and replies with canned JSON — the same fake adapter
/// style the other repository tests use; no Dio mocking package in this repo.
class _FakeAdapter implements HttpClientAdapter {
  final List<String> paths = [];
  Object body = <Object>[];
  int statusCode = 200;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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
  late TrainerClientsRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _FakeAdapter();
    dio.httpClientAdapter = adapter;
    repo = TrainerClientsRepository(dio);
  });

  test('reads the whole client row from a single GET /trainer/clients', () async {
    adapter.body = [
      {
        'clientId': 7,
        'clientEmail': 'anna@example.com',
        'clientFirstName': 'Anna',
        'clientLastName': 'Kovacs',
        'activeSince': '2026-06-01T08:30:00Z',
        'weightTrend': [
          {'date': '2026-07-01', 'weightKg': 62.5},
          {'date': '2026-07-08', 'weightKg': 62.0},
        ],
        'assignedPlanCount': 3,
        'workoutsPerWeek': 2,
        'lastActivityAt': '2026-07-10T18:00:00Z',
        'lastWeightAt': '2026-07-08',
        'missedWorkoutCount': 1,
      },
    ];

    final clients = await repo.fetchActiveClients();

    expect(adapter.paths.single, '/trainer/clients');
    final client = clients.single;
    expect(client.userId, 7);
    expect(client.displayName, 'Anna Kovacs');
    expect(client.monogram, 'AK');
    expect(client.assignedPlanCount, 3);
    expect(client.workoutsPerWeek, 2);
    expect(client.missedWorkoutCount, 1);
    expect(client.weightTrend.map((p) => p.weightKg), [62.5, 62.0]);
  });

  test('a bare LocalDate is read as UTC midnight, not local midnight', () async {
    adapter.body = [
      {
        'clientId': 1,
        'clientEmail': 'a@example.com',
        'activeSince': '2026-06-01T00:00:00Z',
        'weightTrend': <Object>[],
        'assignedPlanCount': 0,
        'workoutsPerWeek': 0,
        'lastActivityAt': null,
        'lastWeightAt': '2026-07-08',
        'missedWorkoutCount': 0,
      },
    ];

    final client = (await repo.fetchActiveClients()).single;

    // The web reads the same field through `new Date("2026-07-08")`, which is
    // UTC — parsing it as local time would shift every "days since weigh-in"
    // by a day for anyone east or west of UTC, and with it the flag and the
    // sort order.
    expect(client.lastWeightAt, DateTime.utc(2026, 7, 8));
    expect(client.lastWeightAt!.isUtc, isTrue);
  });

  test('a client who never logged anything comes back with null facts', () async {
    adapter.body = [
      {
        'clientId': 2,
        'clientEmail': 'new@example.com',
        'activeSince': '2026-07-11T00:00:00Z',
        'weightTrend': <Object>[],
        'assignedPlanCount': 0,
        'workoutsPerWeek': 0,
        'lastActivityAt': null,
        'lastWeightAt': null,
        'missedWorkoutCount': 0,
      },
    ];

    final client = (await repo.fetchActiveClients()).single;

    expect(client.lastActivityAt, isNull);
    expect(client.lastWeightAt, isNull);
    // No profile name yet — the card falls back to the email address.
    expect(client.displayName, 'new@example.com');
    expect(client.monogram, 'N');
  });
}
