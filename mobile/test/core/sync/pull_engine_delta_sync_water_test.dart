import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// Routes GET /water-entries to whichever handler the test configures, based
/// on whether the request carries `updatedSince` (the delta branch) or not
/// (the full-pull bootstrap branch) — mirrors the real backend contract.
/// Every other pullAll() entity gets an empty, harmless response.
class _WaterEntriesAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> fullPullEntries = [];
  List<Map<String, dynamic>> deltaPullEntries = [];

  final List<Uri> requestedUris = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/water-entries') {
      requestedUris.add(options.uri);
      final isDelta = options.uri.queryParameters.containsKey('updatedSince');
      // The full-pull path (findAll()) returns a plain JSON array; only the
      // delta path (updatedSince present) returns a Spring Data Page.
      final body = isDelta ? {'content': deltaPullEntries, 'last': true} : fullPullEntries;
      return ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      '[]',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _waterEntry(
  int id,
  double volumeLiters, {
  String? updatedAt,
  String? deletedAt,
}) =>
    {
      'id': id,
      'consumedAt': '2026-06-01T09:00:00.000Z',
      'volumeLiters': volumeLiters,
      'sourceId': null,
      'sourceName': null,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
    };

void main() {
  late AppDatabase db;
  late Dio dio;
  late _WaterEntriesAdapter adapter;
  late PullEngine pullEngine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _WaterEntriesAdapter();
    dio.httpClientAdapter = adapter;
    pullEngine = PullEngine(db, dio);
  });

  tearDown(() => db.close());

  test('first pull (no cursor) takes the full-pull path and seeds a cursor '
      'from the max updatedAt observed', () async {
    adapter.fullPullEntries = [
      _waterEntry(1, 0.5, updatedAt: '2026-06-01T09:00:00.000Z'),
      _waterEntry(2, 0.3, updatedAt: '2026-06-01T09:05:00.000Z'),
    ];

    await pullEngine.pullAll();

    expect(adapter.requestedUris.single.queryParameters.containsKey('updatedSince'), isFalse);
    final rows = await db.select(db.waterEntries).get();
    expect(rows.map((r) => r.volumeLiters).toSet(), {0.5, 0.3});

    final cursor = await (db.select(db.syncCursors)
          ..where((t) => t.entityType.equals('water_entries')))
        .getSingle();
    expect(
      cursor.lastSyncedAt.toUtc(),
      DateTime.parse('2026-06-01T09:05:00.000Z').subtract(const Duration(seconds: 10)),
    );
  });

  test('a device with an existing cursor takes the delta path, sending it as '
      'updatedSince, and upserts the returned row', () async {
    await db.into(db.syncCursors).insert(SyncCursorsCompanion.insert(
          entityType: 'water_entries',
          lastSyncedAt: DateTime.parse('2026-06-01T08:00:00.000Z'),
        ));
    adapter.deltaPullEntries = [
      _waterEntry(3, 0.7, updatedAt: '2026-06-01T08:30:00.000Z'),
    ];

    await pullEngine.pullAll();

    expect(
      adapter.requestedUris.single.queryParameters['updatedSince'],
      '2026-06-01T08:00:00.000Z',
    );
    final rows = await db.select(db.waterEntries).get();
    expect(rows.map((r) => r.volumeLiters).toList(), [0.7]);
  });

  test('a tombstoned row (deletedAt set) in the delta feed deletes the local '
      'water entry instead of upserting it', () async {
    await db.into(db.waterEntries).insert(WaterEntriesCompanion.insert(
          clientId: 'local-1',
          serverId: const Value(5),
          volumeLiters: 0.5,
          consumedAt: DateTime.parse('2026-06-01T08:00:00.000Z'),
        ));
    await db.into(db.syncCursors).insert(SyncCursorsCompanion.insert(
          entityType: 'water_entries',
          lastSyncedAt: DateTime.parse('2026-06-01T08:00:00.000Z'),
        ));
    adapter.deltaPullEntries = [
      _waterEntry(5, 0.5, updatedAt: '2026-06-01T08:30:00.000Z', deletedAt: '2026-06-01T08:30:00.000Z'),
    ];

    await pullEngine.pullAll();

    expect(await db.select(db.waterEntries).get(), isEmpty);
  });

  test('a delta pull that returns nothing leaves the cursor untouched, '
      'rather than advancing it to the wall clock', () async {
    final original = DateTime.parse('2026-06-01T08:00:00.000Z');
    await db.into(db.syncCursors).insert(SyncCursorsCompanion.insert(
          entityType: 'water_entries',
          lastSyncedAt: original,
        ));
    adapter.deltaPullEntries = [];

    await pullEngine.pullAll();

    final cursor = await (db.select(db.syncCursors)
          ..where((t) => t.entityType.equals('water_entries')))
        .getSingle();
    expect(cursor.lastSyncedAt.toUtc(), original);
  });
}
