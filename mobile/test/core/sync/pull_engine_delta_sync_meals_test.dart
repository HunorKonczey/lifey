import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// Routes GET /meals to whichever handler the test configures, based on
/// whether the request carries `updatedSince` (the delta branch) or not (the
/// full-pull bootstrap branch) — mirrors the real backend contract. Every
/// other pullAll() entity gets an empty, harmless response.
class _MealsAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>> fullPullMeals = [];
  List<Map<String, dynamic>> deltaPullMeals = [];

  final List<Uri> requestedMealsUris = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/meals') {
      requestedMealsUris.add(options.uri);
      final isDelta = options.uri.queryParameters.containsKey('updatedSince');
      // The full-pull path (findAll()) returns a plain JSON array; only the
      // delta path (updatedSince present) returns a Spring Data Page.
      final body = isDelta ? {'content': deltaPullMeals, 'last': true} : fullPullMeals;
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

Map<String, dynamic> _meal(
  int id, {
  required List<Map<String, dynamic>> entries,
  String? updatedAt,
  String? deletedAt,
}) =>
    {
      'id': id,
      'dateTime': '2026-06-01T12:00:00.000Z',
      'mealType': 'LUNCH',
      'name': null,
      'entries': entries,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
    };

Map<String, dynamic> _entry(int foodId, double grams) =>
    {'foodId': foodId, 'quantityInGrams': grams};

void main() {
  late AppDatabase db;
  late Dio dio;
  late _MealsAdapter adapter;
  late PullEngine pullEngine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _MealsAdapter();
    dio.httpClientAdapter = adapter;
    pullEngine = PullEngine(db, dio);
  });

  tearDown(() => db.close());

  /// Seeds a local food row directly (bypassing the network) so meal-entry
  /// upserts can resolve `foodId` -> local clientId without exercising the
  /// foods pull separately.
  Future<void> seedFood(String clientId, int serverId) async {
    await db.into(db.foods).insert(FoodsCompanion.insert(
          clientId: clientId,
          serverId: Value(serverId),
          name: 'Food $serverId',
          caloriesPer100g: 100,
          proteinPer100g: 5,
        ));
  }

  test('first pull (no cursor) takes the full-pull path, stores entries, and '
      'seeds a cursor from the max updatedAt observed', () async {
    await seedFood('food-1', 1);
    adapter.fullPullMeals = [
      _meal(10, entries: [_entry(1, 150)], updatedAt: '2026-06-01T10:00:00.000Z'),
    ];

    await pullEngine.pullAll();

    expect(adapter.requestedMealsUris.single.queryParameters.containsKey('updatedSince'), isFalse);
    final meals = await db.select(db.meals).get();
    expect(meals, hasLength(1));
    final entries = await db.select(db.mealEntries).get();
    expect(entries, hasLength(1));
    expect(entries.single.quantityInGrams, 150);

    final cursor = await (db.select(db.syncCursors)
          ..where((t) => t.entityType.equals('meals')))
        .getSingle();
    expect(
      cursor.lastSyncedAt.toUtc(),
      DateTime.parse('2026-06-01T10:00:00.000Z').subtract(const Duration(seconds: 10)),
    );
  });

  test('a delta upsert of an already-known meal fully replaces its entries — '
      'not just on first insert — so an entry-only edit on a second device '
      'reaches this device', () async {
    // Seed a meal + one entry as if a prior full pull already brought it in.
    await seedFood('food-1', 1);
    await seedFood('food-2', 2);
    await db.into(db.meals).insert(MealsCompanion.insert(
          clientId: 'meal-1',
          serverId: const Value(10),
          mealDateTime: DateTime.parse('2026-06-01T12:00:00.000Z'),
          mealType: 'LUNCH',
        ));
    await db.into(db.mealEntries).insert(MealEntriesCompanion.insert(
          clientId: 'entry-old',
          mealClientId: 'meal-1',
          foodClientId: 'food-1',
          quantityInGrams: 100,
        ));
    await db.into(db.syncCursors).insert(SyncCursorsCompanion.insert(
          entityType: 'meals',
          lastSyncedAt: DateTime.parse('2026-06-01T11:00:00.000Z'),
        ));

    // Server reports the meal again (its updatedAt bumped by the
    // entry-only edit), now with a different entry: food swapped, grams changed.
    adapter.deltaPullMeals = [
      _meal(10, entries: [_entry(2, 200)], updatedAt: '2026-06-01T11:30:00.000Z'),
    ];

    await pullEngine.pullAll();

    final entries = await db.select(db.mealEntries).get();
    expect(entries, hasLength(1));
    expect(entries.single.foodClientId, 'food-2');
    expect(entries.single.quantityInGrams, 200);
  });

  test('a tombstoned meal (deletedAt set) in the delta feed deletes the local '
      'meal and its entries', () async {
    await seedFood('food-1', 1);
    await db.into(db.meals).insert(MealsCompanion.insert(
          clientId: 'meal-1',
          serverId: const Value(10),
          mealDateTime: DateTime.parse('2026-06-01T12:00:00.000Z'),
          mealType: 'LUNCH',
        ));
    await db.into(db.mealEntries).insert(MealEntriesCompanion.insert(
          clientId: 'entry-old',
          mealClientId: 'meal-1',
          foodClientId: 'food-1',
          quantityInGrams: 100,
        ));
    await db.into(db.syncCursors).insert(SyncCursorsCompanion.insert(
          entityType: 'meals',
          lastSyncedAt: DateTime.parse('2026-06-01T11:00:00.000Z'),
        ));

    adapter.deltaPullMeals = [
      _meal(10, entries: const [], updatedAt: '2026-06-01T11:30:00.000Z', deletedAt: '2026-06-01T11:30:00.000Z'),
    ];

    await pullEngine.pullAll();

    expect(await db.select(db.meals).get(), isEmpty);
    expect(await db.select(db.mealEntries).get(), isEmpty);
  });
}
