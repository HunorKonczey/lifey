import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// Routes GET /foods to whichever handler the test configures, based on
/// whether the request carries `updatedSince` (the delta branch) or not (the
/// full-pull bootstrap branch) — mirrors the real backend contract from
/// docs/15-delta-sync.md. Every other pullAll() entity gets an empty,
/// harmless response (each _pull* is guarded).
class _FoodsAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> fullPullFoods = [];
  List<Map<String, dynamic>> deltaPullFoods = [];

  final List<Uri> requestedFoodsUris = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/foods') {
      requestedFoodsUris.add(options.uri);
      final isDelta = options.uri.queryParameters.containsKey('updatedSince');
      final content = isDelta ? deltaPullFoods : fullPullFoods;
      final body = {'content': content, 'last': true};
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

Map<String, dynamic> _food(
  int id,
  String name, {
  String? updatedAt,
  String? deletedAt,
}) =>
    {
      'id': id,
      'name': name,
      'caloriesPer100g': 100.0,
      'proteinPer100g': 5.0,
      'carbsPer100g': 10.0,
      'fatPer100g': 2.0,
      'barcode': null,
      'hidden': deletedAt != null, // tombstoned rows come back hidden=true
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
    };

void main() {
  late AppDatabase db;
  late Dio dio;
  late _FoodsAdapter adapter;
  late PullEngine pullEngine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _FoodsAdapter();
    dio.httpClientAdapter = adapter;
    pullEngine = PullEngine(db, dio);
  });

  tearDown(() => db.close());

  test('first pull (no cursor) takes the full-pull path and seeds a cursor '
      'from the max updatedAt observed, minus the overlap window', () async {
    adapter.fullPullFoods = [
      _food(1, 'Apple', updatedAt: '2026-06-01T10:00:00.000Z'),
      _food(2, 'Banana', updatedAt: '2026-06-01T10:05:00.000Z'),
    ];

    await pullEngine.pullAll();

    expect(adapter.requestedFoodsUris.single.queryParameters.containsKey('updatedSince'), isFalse);
    final names = (await db.select(db.foods).get()).map((f) => f.name).toSet();
    expect(names, {'Apple', 'Banana'});

    final cursor = await (db.select(db.syncCursors)
          ..where((t) => t.entityType.equals('foods')))
        .getSingle();
    // Drift round-trips DateTime as local-time (same instant, isUtc: false),
    // so compare in UTC — Dart's DateTime.== also checks the isUtc flag, not
    // just the instant (see docs/15-delta-sync.md's own cursor handling,
    // which always normalizes via .toUtc() for exactly this reason).
    expect(
      cursor.lastSyncedAt.toUtc(),
      DateTime.parse('2026-06-01T10:05:00.000Z').subtract(const Duration(seconds: 10)),
    );
  });

  test('a device with an existing cursor takes the delta path, sending it as '
      'updatedSince', () async {
    await db.into(db.syncCursors).insert(SyncCursorsCompanion.insert(
          entityType: 'foods',
          lastSyncedAt: DateTime.parse('2026-06-01T09:00:00.000Z'),
        ));
    adapter.deltaPullFoods = [_food(3, 'Carrot', updatedAt: '2026-06-01T09:30:00.000Z')];

    await pullEngine.pullAll();

    expect(
      adapter.requestedFoodsUris.single.queryParameters['updatedSince'],
      '2026-06-01T09:00:00.000Z',
    );
    final names = (await db.select(db.foods).get()).map((f) => f.name).toSet();
    expect(names, {'Carrot'});
  });

  test('a tombstoned row (deletedAt set) in the delta feed deletes the local '
      'food instead of upserting it', () async {
    // Seed a local food as if an earlier full pull had already brought it in.
    await db.into(db.foods).insert(FoodsCompanion.insert(
          clientId: 'local-1',
          serverId: const Value(5),
          name: 'Old Rice',
          caloriesPer100g: 130,
          proteinPer100g: 2.7,
        ));
    await db.into(db.syncCursors).insert(SyncCursorsCompanion.insert(
          entityType: 'foods',
          lastSyncedAt: DateTime.parse('2026-06-01T09:00:00.000Z'),
        ));
    adapter.deltaPullFoods = [
      _food(5, 'Old Rice', updatedAt: '2026-06-01T09:30:00.000Z', deletedAt: '2026-06-01T09:30:00.000Z'),
    ];

    await pullEngine.pullAll();

    expect(await db.select(db.foods).get(), isEmpty);
  });

  test('a delta pull that returns nothing leaves the cursor untouched, '
      'rather than advancing it to the wall clock', () async {
    final original = DateTime.parse('2026-06-01T09:00:00.000Z');
    await db.into(db.syncCursors).insert(SyncCursorsCompanion.insert(
          entityType: 'foods',
          lastSyncedAt: original,
        ));
    adapter.deltaPullFoods = [];

    await pullEngine.pullAll();

    final cursor = await (db.select(db.syncCursors)
          ..where((t) => t.entityType.equals('foods')))
        .getSingle();
    expect(cursor.lastSyncedAt.toUtc(), original);
  });
}
