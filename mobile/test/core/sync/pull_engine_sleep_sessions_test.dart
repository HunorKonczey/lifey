import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// Serves GET /sleep-sessions: a plain list for the full-pull bootstrap and a
/// page for the delta branch (`updatedSince`); every other entity gets an
/// empty, harmless response.
class _SleepAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> full = [];
  List<Map<String, dynamic>> delta = [];
  final deltaSince = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object body = <Object>[];
    if (options.path == '/sleep-sessions') {
      final since = options.uri.queryParameters['updatedSince'];
      if (since != null) deltaSince.add(since);
      body = since != null ? {'content': delta, 'last': true} : full;
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _json(
  int id, {
  int? deep = 80,
  String? recordId,
  String updatedAt = '2026-11-21T07:00:00Z',
  String? deletedAt,
}) =>
    {
      'id': id,
      'startedAt': '2026-11-20T22:40:00Z',
      'endedAt': '2026-11-21T06:10:00Z',
      'asleepMinutes': deep == null ? null : 420,
      'deepMinutes': deep,
      'lightMinutes': deep == null ? null : 230,
      'remMinutes': deep == null ? null : 110,
      'awakeMinutes': deep == null ? null : 30,
      'sourceAppName': 'Garmin Connect',
      'healthRecordId': recordId ?? 'hc-$id',
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
    };

/// docs/integrations/89 G2.2: sleep sessions reach a fresh install and a
/// second device through the pull, and tombstones remove them again.
void main() {
  late AppDatabase db;
  late _SleepAdapter adapter;
  late PullEngine pull;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _SleepAdapter();
    dio.httpClientAdapter = adapter;
    pull = PullEngine(db, dio);
  });

  tearDown(() => db.close());

  test('first pull is a full pull: inserts every field and drops rows the server no longer has', () async {
    await db.into(db.sleepSessions).insert(SleepSessionsCompanion.insert(
          clientId: 'stale',
          serverId: const Value(99),
          startedAt: DateTime.utc(2026, 1, 1),
          endedAt: DateTime.utc(2026, 1, 1, 7),
        ));
    adapter.full = [_json(1), _json(2, deep: null)];

    await pull.pullAll();

    final rows = await db.select(db.sleepSessions).get();
    expect(rows.map((r) => r.serverId), unorderedEquals([1, 2]));
    final first = rows.firstWhere((r) => r.serverId == 1);
    expect(first.startedAt.toUtc(), DateTime.utc(2026, 11, 20, 22, 40));
    expect(first.endedAt.toUtc(), DateTime.utc(2026, 11, 21, 6, 10));
    expect([first.asleepMinutes, first.deepMinutes, first.lightMinutes, first.remMinutes, first.awakeMinutes],
        [420, 80, 230, 110, 30]);
    expect(first.sourceAppName, 'Garmin Connect');
    expect(first.healthRecordId, 'hc-1');
    expect(rows.firstWhere((r) => r.serverId == 2).deepMinutes, isNull);
  });

  test('the next pull is a delta: new rows land, tombstones remove theirs', () async {
    adapter.full = [_json(1), _json(2)];
    await pull.pullAll(); // seeds the cursor

    adapter.delta = [
      _json(2, updatedAt: '2026-11-22T08:00:00Z', deletedAt: '2026-11-22T08:00:00Z'),
      _json(3, updatedAt: '2026-11-22T09:00:00Z'),
    ];
    await pull.pullAll();

    expect(adapter.deltaSince, isNotEmpty);
    final rows = await db.select(db.sleepSessions).get();
    expect(rows.map((r) => r.serverId), unorderedEquals([1, 3]));
  });

  test('a row with a pending local delete is neither overwritten nor removed by a pull', () async {
    await db.into(db.sleepSessions).insert(SleepSessionsCompanion.insert(
          clientId: 'local',
          serverId: const Value(1),
          startedAt: DateTime.utc(2026, 11, 20, 22, 40),
          endedAt: DateTime.utc(2026, 11, 21, 6, 10),
          deepMinutes: const Value(10),
        ));
    await db.into(db.pendingOperations).insert(PendingOperationsCompanion.insert(
          clientId: 'local',
          entityType: 'sleep_session',
          operation: 'delete',
          payloadJson: '{}',
          createdAt: DateTime.utc(2026, 11, 21),
        ));
    adapter.full = [_json(1, deep: 99)];
    await pull.pullAll();
    expect((await db.select(db.sleepSessions).getSingle()).deepMinutes, 10);

    adapter.delta = [_json(1, updatedAt: '2026-11-22T08:00:00Z', deletedAt: '2026-11-22T08:00:00Z')];
    await pull.pullAll();
    expect(await db.select(db.sleepSessions).get(), hasLength(1));
  });
}
