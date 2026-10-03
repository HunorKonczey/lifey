import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// Serves GET /measurements: a plain list for the full-pull bootstrap and a
/// page for the delta branch (`updatedSince`); every other entity gets an
/// empty, harmless response.
class _MeasurementsAdapter implements HttpClientAdapter {
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
    if (options.path == '/measurements') {
      body = options.uri.queryParameters.containsKey('updatedSince')
          ? {'content': delta, 'last': true}
          : full;
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

Map<String, dynamic> _json(int id, String site, double cm, {String? updatedAt, String? deletedAt}) => {
      'id': id,
      'date': '2026-06-18',
      'site': site,
      'valueCm': cm,
      'updatedAt': updatedAt ?? '2026-06-18T08:00:00Z',
      'deletedAt': deletedAt,
    };

void main() {
  late AppDatabase db;
  late _MeasurementsAdapter adapter;
  late PullEngine pull;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _MeasurementsAdapter();
    dio.httpClientAdapter = adapter;
    pull = PullEngine(db, dio);
  });

  tearDown(() => db.close());

  test('first pull is a full pull: inserts rows and drops local rows the server no longer has', () async {
    await db.into(db.bodyMeasurements).insert(BodyMeasurementsCompanion.insert(
          clientId: 'stale',
          serverId: const Value(99),
          date: DateTime(2026, 1, 1),
          site: 'WAIST',
          valueCm: 80,
          recordedAt: DateTime(2026, 1, 1),
        ));
    adapter.full = [_json(1, 'WAIST', 82.5), _json(2, 'ARM', 35)];

    await pull.pullAll();

    final rows = await db.select(db.bodyMeasurements).get();
    expect(rows.map((r) => r.serverId), unorderedEquals([1, 2]));
    expect(rows.firstWhere((r) => r.serverId == 1).valueCm, 82.5);
  });

  test('delta pull upserts changes and removes tombstoned rows', () async {
    adapter.full = [_json(1, 'WAIST', 82.5), _json(2, 'ARM', 35)];
    await pull.pullAll(); // seeds the cursor

    adapter.delta = [
      _json(1, 'WAIST', 81.0, updatedAt: '2026-06-19T08:00:00Z'),
      _json(2, 'ARM', 35, updatedAt: '2026-06-19T09:00:00Z', deletedAt: '2026-06-19T09:00:00Z'),
      _json(3, 'HIPS', 95, updatedAt: '2026-06-19T10:00:00Z'),
    ];
    await pull.pullAll();

    final rows = await db.select(db.bodyMeasurements).get();
    expect(rows.map((r) => r.serverId), unorderedEquals([1, 3]));
    expect(rows.firstWhere((r) => r.serverId == 1).valueCm, 81.0);
  });

  test('a row with a pending local operation is not overwritten by a pull', () async {
    await db.into(db.bodyMeasurements).insert(BodyMeasurementsCompanion.insert(
          clientId: 'local',
          serverId: const Value(1),
          date: DateTime(2026, 6, 18),
          site: 'WAIST',
          valueCm: 70,
          recordedAt: DateTime(2026, 6, 18),
        ));
    await db.into(db.pendingOperations).insert(PendingOperationsCompanion.insert(
          clientId: 'local',
          entityType: 'body_measurement',
          operation: 'update',
          payloadJson: '{}',
          createdAt: DateTime(2026, 6, 18),
        ));
    adapter.full = [_json(1, 'WAIST', 99)];

    await pull.pullAll();

    expect((await db.select(db.bodyMeasurements).getSingle()).valueCm, 70);
  });
}
