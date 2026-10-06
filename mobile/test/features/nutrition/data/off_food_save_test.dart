import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/nutrition/data/food_repository.dart';
import 'package:lifey/features/nutrition/domain/off_food_plan.dart';
import 'package:lifey/features/nutrition/domain/off_search.dart';

/// docs/84 Prompt 10 against a real (in-memory) database: picking an OpenFoodFacts result saves the food the way every
/// other food is saved — a local row and one outbox entry, no network — and picking the same product again finds that
/// food instead of creating a second one.
class _RecordingAdapter implements HttpClientAdapter {
  final requests = <({String method, String path, Object? body})>[];
  bool offline = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (offline) throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    requests.add((method: options.method, path: options.path, body: options.data));
    return ResponseBody.fromString(jsonEncode({'id': 41}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

/// The writer's own fire-and-forget sync would race the test's explicit one.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

const _item = OffSearchItem(
  barcode: '4056489827702',
  name: 'Csirkemell',
  brand: 'Pikok',
  caloriesPer100g: 110,
  proteinPer100g: 14,
  carbsPer100g: 2.4,
  fatPer100g: null,
);

void main() {
  late AppDatabase db;
  late _RecordingAdapter adapter;
  late SyncEngine engine;
  late FoodRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _RecordingAdapter();
    dio.httpClientAdapter = adapter;
    engine = SyncEngine(db, dio);
    repo = FoodRepository(db, OutboxWriter(db, _NoopSyncEngine(db, dio)));
  });

  tearDown(() => db.close());

  /// What the sheet does for a tap: plan from the user own foods, then create (or not).
  Future<String?> pick(OffSearchItem item) async {
    final plan = planOffFood(item, await repo.watchAll().first);
    return switch (plan) {
      UseExistingFood(:final food) => food.clientId,
      CreateOffFood(:final name) => await repo.create(
          name: name, calories: item.caloriesPer100g, protein: item.proteinPer100g, carbs: item.carbsPer100g, fat: item.fatPer100g, barcode: item.barcode),
    };
  }

  test('the first pick writes one food row and one outbox create — and touches no network', () async {
    adapter.offline = true; // the user is offline

    final clientId = await pick(_item);

    final foods = await db.select(db.foods).get();
    expect(foods, hasLength(1));
    expect(foods.single.clientId, clientId);
    expect(foods.single.name, 'Csirkemell');
    expect(foods.single.barcode, '4056489827702');
    expect(foods.single.carbsPer100g, 2.4);
    expect(foods.single.fatPer100g, isNull);
    expect(foods.single.hidden, isFalse);
    final ops = await db.select(db.pendingOperations).get();
    expect(ops, hasLength(1));
    expect(ops.single.entityType, 'food');
    expect(ops.single.clientId, clientId);
    expect(adapter.requests, isEmpty);
  });

  test('picking the same product again finds the saved food: no second row, no second outbox entry', () async {
    final first = await pick(_item);
    final second = await pick(_item);

    expect(second, first);
    expect(await db.select(db.foods).get(), hasLength(1));
    expect(await db.select(db.pendingOperations).get(), hasLength(1));
  });

  test('it syncs later like any food: one POST /foods once there is a connection', () async {
    adapter.offline = true;
    await pick(_item);
    await engine.sync(); // still offline: nothing goes out, the entry stays queued
    expect(adapter.requests, isEmpty);
    expect(await db.select(db.pendingOperations).get(), hasLength(1));

    adapter.offline = false;
    await engine.sync();

    expect(adapter.requests.map((r) => '${r.method} ${r.path}'), ['POST /foods']);
    expect((adapter.requests.single.body as Map)['barcode'], '4056489827702');
    expect((await db.select(db.foods).getSingle()).serverId, 41);
  });

  test('a different product with the same name is saved as "Name (Brand)", and the first one is untouched', () async {
    await pick(_item);
    const other = OffSearchItem(barcode: '999', name: 'Csirkemell', brand: 'Aldi', caloriesPer100g: 119, proteinPer100g: 14);

    await pick(other);

    final names = (await db.select(db.foods).get()).map((f) => f.name).toSet();
    expect(names, {'Csirkemell', 'Csirkemell (Aldi)'});
  });
}
