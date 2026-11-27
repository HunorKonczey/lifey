import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// Serves GET /vitals: a plain list for the full-pull bootstrap and a page for
/// the delta branch (`updatedSince`); every other entity gets an empty,
/// harmless response.
class _VitalsAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> full = [];
  List<Map<String, dynamic>> delta = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object body = <Object>[];
    if (options.path == '/vitals') {
      body = options.uri.queryParameters.containsKey('updatedSince') ? {'content': delta, 'last': true} : full;
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
  int id,
  String date, {
  int? restingHr = 52,
  double? hrvMs,
  String? method,
  String updatedAt = '2026-11-21T08:00:00Z',
  String? deletedAt,
}) =>
    {
      'id': id,
      'date': date,
      'restingHr': restingHr,
      'hrvMs': hrvMs,
      'hrvMethod': method,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
    };

/// docs/integrations/89 G3.2: daily vitals reach a fresh install and a second
/// device through the pull, and tombstones remove them again.
void main() {
  late AppDatabase db;
  late _VitalsAdapter adapter;
  late PullEngine pull;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _VitalsAdapter();
    dio.httpClientAdapter = adapter;
    pull = PullEngine(db, dio);
  });

  tearDown(() => db.close());

  test('first pull is a full pull: inserts every value and drops rows the server no longer has', () async {
    await db.into(db.dailyVitalsTable).insert(DailyVitalsTableCompanion.insert(
          clientId: 'stale',
          serverId: const Value(99),
          date: DateTime(2026, 1, 1),
          restingHr: const Value(60),
        ));
    adapter.full = [
      _json(1, '2026-11-21', hrvMs: 48.5, method: 'RMSSD'),
      _json(2, '2026-11-20', restingHr: null, hrvMs: 40, method: 'SDNN'),
    ];

    await pull.pullAll();

    final rows = await db.select(db.dailyVitalsTable).get();
    expect(rows.map((r) => r.serverId), unorderedEquals([1, 2]));
    final first = rows.firstWhere((r) => r.serverId == 1);
    expect(first.date, DateTime(2026, 11, 21));
    expect(first.restingHr, 52);
    expect(first.hrvMs, 48.5);
    expect(first.hrvMethod, 'RMSSD');
    expect(rows.firstWhere((r) => r.serverId == 2).restingHr, isNull);
  });

  test('the next pull is a delta: changes land, tombstones remove their rows', () async {
    adapter.full = [_json(1, '2026-11-21'), _json(2, '2026-11-20')];
    await pull.pullAll(); // seeds the cursor

    adapter.delta = [
      _json(1, '2026-11-21', restingHr: 50, updatedAt: '2026-11-22T08:00:00Z'),
      _json(2, '2026-11-20', updatedAt: '2026-11-22T09:00:00Z', deletedAt: '2026-11-22T09:00:00Z'),
      _json(3, '2026-11-22', updatedAt: '2026-11-22T10:00:00Z'),
    ];
    await pull.pullAll();

    final rows = await db.select(db.dailyVitalsTable).get();
    expect(rows.map((r) => r.serverId), unorderedEquals([1, 3]));
    expect(rows.firstWhere((r) => r.serverId == 1).restingHr, 50);
  });

  test('a row with a pending local operation is not overwritten by a pull', () async {
    await db.into(db.dailyVitalsTable).insert(DailyVitalsTableCompanion.insert(
          clientId: 'local',
          serverId: const Value(1),
          date: DateTime(2026, 11, 21),
          restingHr: const Value(49),
        ));
    await db.into(db.pendingOperations).insert(PendingOperationsCompanion.insert(
          clientId: 'local',
          entityType: 'daily_vitals',
          operation: 'update',
          payloadJson: '{}',
          createdAt: DateTime(2026, 11, 21),
        ));
    adapter.full = [_json(1, '2026-11-21', restingHr: 60)];

    await pull.pullAll();

    expect((await db.select(db.dailyVitalsTable).getSingle()).restingHr, 49);
  });

  test('a day recorded offline and not yet synced does not get a second row from the pull', () async {
    await db.into(db.dailyVitalsTable).insert(DailyVitalsTableCompanion.insert(
          clientId: 'offline',
          date: DateTime(2026, 11, 21),
          restingHr: const Value(49),
        ));
    await db.into(db.pendingOperations).insert(PendingOperationsCompanion.insert(
          clientId: 'offline',
          entityType: 'daily_vitals',
          operation: 'create',
          payloadJson: '{}',
          createdAt: DateTime(2026, 11, 21),
        ));
    adapter.full = [_json(5, '2026-11-21', restingHr: 60)];

    await pull.pullAll();

    final row = await db.select(db.dailyVitalsTable).getSingle();
    expect(row.clientId, 'offline');
    expect(row.restingHr, 49);
  });
}
