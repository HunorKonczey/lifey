import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// Serves GET /weights (a plain list for the first, full pull); every other entity gets an empty response.
class _WeightsAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> full = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final Object body = options.path == '/weights' && !options.uri.queryParameters.containsKey('updatedSince') ? full : <Object>[];
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _json(int id, {String? recordedAt, String? note}) => {
      'id': id,
      'date': '2026-06-18',
      'weight': 80.5,
      'updatedAt': '2026-06-18T08:00:00Z',
      'deletedAt': null,
      'recordedAt': recordedAt,
      'note': note,
    };

/// LIF-115: a weigh-in's time and note come from the server, so one logged on another device (or offline here) keeps them.
void main() {
  late AppDatabase db;
  late _WeightsAdapter adapter;
  late PullEngine pull;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _WeightsAdapter();
    dio.httpClientAdapter = adapter;
    pull = PullEngine(db, dio);
  });

  tearDown(() => db.close());

  test('a new row takes the recordedAt and note', () async {
    adapter.full = [_json(1, recordedAt: '2026-06-18T05:02:00Z', note: 'fasted')];

    await pull.pullAll();

    final row = (await db.select(db.weightEntries).get()).single;
    expect(row.recordedAt.toUtc(), DateTime.utc(2026, 6, 18, 5, 2));
    expect(row.note, 'fasted');
  });

  test('an existing row is updated with the recordedAt and note', () async {
    await db.into(db.weightEntries).insert(WeightEntriesCompanion.insert(
          clientId: 'local',
          serverId: const Value(1),
          date: DateTime(2026, 6, 18),
          weight: 80.5,
          recordedAt: DateTime(2026, 6, 18, 12, 0),
        ));
    adapter.full = [_json(1, recordedAt: '2026-06-18T05:02:00Z', note: 'after a run')];

    await pull.pullAll();

    final row = (await db.select(db.weightEntries).get()).single;
    expect(row.clientId, 'local');
    expect(row.recordedAt.toUtc(), DateTime.utc(2026, 6, 18, 5, 2));
    expect(row.note, 'after a run');
  });

  test('an older server (no recordedAt) leaves the time of an existing row alone', () async {
    final kept = DateTime(2026, 6, 18, 12, 0);
    await db.into(db.weightEntries).insert(WeightEntriesCompanion.insert(
          clientId: 'local',
          serverId: const Value(1),
          date: DateTime(2026, 6, 18),
          weight: 80.5,
          recordedAt: kept,
        ));
    adapter.full = [_json(1)];

    await pull.pullAll();

    final row = (await db.select(db.weightEntries).get()).single;
    expect(row.recordedAt, kept);
    expect(row.note, isNull);
  });
}
