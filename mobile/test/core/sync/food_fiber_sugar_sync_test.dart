import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/pull_engine.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/nutrition/data/food_repository.dart';
import 'package:lifey/features/nutrition/domain/food.dart';

/// Serves GET /foods as one page; every other entity gets an empty response.
class _FoodsAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> full = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final Object body = options.path == '/foods' ? {'content': full, 'last': true} : <Object>[];
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

Map<String, dynamic> _json(int id, {double? fiber, double? sugar}) => {
      'id': id,
      'name': 'Oats',
      'caloriesPer100g': 370,
      'proteinPer100g': 13,
      'carbsPer100g': 60,
      'fatPer100g': 7,
      'fiberPer100g': fiber,
      'sugarPer100g': sugar,
      'barcode': null,
      'hidden': false,
      'updatedAt': '2026-06-18T08:00:00Z',
      'deletedAt': null,
    };

/// LIF-145: fibre and sugars per 100 g travel with a food - out in the outbox payloads, in with a pull. An update must send
/// the stored values back: the server replaces a food's fields, so leaving them out would erase what the web set.
void main() {
  late AppDatabase db;
  late Dio dio;
  late FoodRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    repo = FoodRepository(db, OutboxWriter(db, _NoopSyncEngine(db, dio)));
  });

  tearDown(() => db.close());

  Future<Map<String, dynamic>> lastPayload() async {
    final ops = await db.select(db.pendingOperations).get();
    return jsonDecode(ops.last.payloadJson) as Map<String, dynamic>;
  }

  test('a created food keeps its fibre and sugar locally and sends them', () async {
    await repo.create(name: 'Oats', calories: 370, protein: 13, carbs: 60, fat: 7, fiber: 10, sugar: 1.2);

    final row = (await db.select(db.foods).get()).single;
    expect(row.fiberPer100g, 10);
    expect(row.sugarPer100g, 1.2);
    final payload = await lastPayload();
    expect(payload['fiberPer100g'], 10);
    expect(payload['sugarPer100g'], 1.2);
  });

  test('a food created without them sends null, not zero', () async {
    await repo.create(name: 'Rice', calories: 130, protein: 2.7);

    final payload = await lastPayload();
    expect(payload.containsKey('fiberPer100g'), isTrue);
    expect(payload['fiberPer100g'], isNull);
    expect(payload['sugarPer100g'], isNull);
  });

  test('an update sends the fibre and sugar it was given - including clearing one', () async {
    final clientId = await repo.create(name: 'Oats', calories: 370, protein: 13, fiber: 10, sugar: 1.2);

    await repo.update(clientId, name: 'Oats', calories: 370, protein: 13, fiber: 9, sugar: null);

    final row = (await db.select(db.foods).get()).single;
    expect(row.fiberPer100g, 9);
    expect(row.sugarPer100g, isNull);
    final payload = await lastPayload();
    expect(payload['fiberPer100g'], 9);
    expect(payload['sugarPer100g'], isNull);
  });

  group('servings (LIF-146)', () {
    const glass = FoodServing(name: '1 glass', grams: 200);
    const spoon = FoodServing(name: '1 spoon', grams: 15);

    test('a created food keeps its servings and sends them in order', () async {
      await repo.create(name: 'Milk', calories: 46, protein: 3.4, servings: [glass, spoon]);

      final row = (await db.select(db.foods).get()).single;
      expect(FoodServing.decode(row.servingsJson), [glass, spoon]);
      final payload = await lastPayload();
      expect(payload['servings'], [
        {'name': '1 glass', 'grams': 200.0},
        {'name': '1 spoon', 'grams': 15.0},
      ]);
    });

    test('a food without servings sends an empty list', () async {
      await repo.create(name: 'Rice', calories: 130, protein: 2.7);

      expect((await lastPayload())['servings'], isEmpty);
    });

    test('an update that is not given servings keeps - and re-sends - the stored ones', () async {
      final clientId = await repo.create(name: 'Milk', calories: 46, protein: 3.4, servings: [glass, spoon]);

      await repo.update(clientId, name: 'Milk', calories: 50, protein: 3.4);

      expect(FoodServing.decode((await db.select(db.foods).get()).single.servingsJson), [glass, spoon]);
      expect((await lastPayload())['servings'], hasLength(2));
    });

    test('an update given servings replaces them, an empty list clears them', () async {
      final clientId = await repo.create(name: 'Milk', calories: 46, protein: 3.4, servings: [glass]);

      await repo.update(clientId, name: 'Milk', calories: 46, protein: 3.4, servings: [spoon, glass]);
      expect(FoodServing.decode((await db.select(db.foods).get()).single.servingsJson), [spoon, glass]);

      await repo.update(clientId, name: 'Milk', calories: 46, protein: 3.4, servings: const []);
      expect((await db.select(db.foods).get()).single.servingsJson, isNull);
      expect((await lastPayload())['servings'], isEmpty);
    });
  });

  group('pull', () {
    late _FoodsAdapter adapter;
    late PullEngine pull;

    setUp(() {
      adapter = _FoodsAdapter();
      dio.httpClientAdapter = adapter;
      pull = PullEngine(db, dio);
    });

    test('a food from the server arrives with its fibre and sugar', () async {
      adapter.full = [_json(1, fiber: 10, sugar: 1.2)];

      await pull.pullAll();

      final row = (await db.select(db.foods).get()).single;
      expect(row.fiberPer100g, 10);
      expect(row.sugarPer100g, 1.2);
    });

    test('a food from the server arrives with its servings, in order; a bad entry is dropped (LIF-146)', () async {
      adapter.full = [
        {
          ..._json(1),
          'servings': [
            {'name': '1 glass', 'grams': 200},
            {'name': '', 'grams': 5},
            {'name': '1 spoon', 'grams': 15},
          ],
        },
      ];

      await pull.pullAll();

      final row = (await db.select(db.foods).get()).single;
      expect(FoodServing.decode(row.servingsJson), const [FoodServing(name: '1 glass', grams: 200), FoodServing(name: '1 spoon', grams: 15)]);
    });

    test('a food the server has no figures for stays unknown (null), and a later pull updates it', () async {
      adapter.full = [_json(1)];
      await pull.pullAll();
      var row = (await db.select(db.foods).get()).single;
      expect(row.fiberPer100g, isNull);

      adapter.full = [_json(1, fiber: 3, sugar: 0.5)];
      await db.delete(db.syncCursors).go(); // force another full pull
      await pull.pullAll();
      row = (await db.select(db.foods).get()).single;
      expect(row.fiberPer100g, 3);
      expect(row.sugarPer100g, 0.5);
    });
  });
}
