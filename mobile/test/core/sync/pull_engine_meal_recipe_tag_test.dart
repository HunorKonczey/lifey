import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/pull_engine.dart';

/// Serves GET /meals (full pull) from [meals] and GET /recipes from [recipes]; everything else is an empty list.
class _Adapter implements HttpClientAdapter {
  List<Map<String, dynamic>> meals = [];
  List<Map<String, dynamic>> recipes = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final delta = options.uri.queryParameters.containsKey('updatedSince');
    final Object body = switch (options.path) {
      '/meals' => delta ? {'content': meals, 'last': true} : meals,
      '/recipes' => delta ? {'content': recipes, 'last': true} : recipes,
      _ => [],
    };
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

Map<String, dynamic> _entry(int foodId, double grams, {int? recipeId, String? recipeName}) => {
      'foodId': foodId,
      'quantityInGrams': grams,
      'recipeId': recipeId,
      'recipeName': recipeName,
    };

/// docs/88 section 2.7: a pulled entry's recipe id becomes the recipe's local client id (recipes are pulled before meals);
/// a recipe this device does not know leaves the entry untagged instead of failing the pull.
void main() {
  late AppDatabase db;
  late _Adapter adapter;
  late PullEngine pull;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    adapter = _Adapter();
    pull = PullEngine(db, Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter);
  });

  tearDown(() => db.close());

  Future<void> seedFood(String clientId, int serverId) => db.into(db.foods).insert(FoodsCompanion.insert(
        clientId: clientId,
        serverId: Value(serverId),
        name: 'Food $serverId',
        caloriesPer100g: 100,
        proteinPer100g: 5,
      ));

  /// A recipe this device already has and the server still lists - a full pull drops synced rows the server no longer
  /// lists, so the recipe has to be on both sides.
  Future<void> seedRecipe(String clientId, int serverId) async {
    await db.into(db.recipes).insert(
          RecipesCompanion.insert(clientId: clientId, serverId: Value(serverId), name: 'Chilli'),
        );
    adapter.recipes = [
      {
        'id': serverId,
        'name': 'Chilli',
        'description': null,
        'favorite': false,
        'servings': 1,
        'ingredients': <Object>[],
        'updatedAt': '2026-05-01T00:00:00.000Z',
        'deletedAt': null,
      },
    ];
  }

  Map<String, dynamic> meal(List<Map<String, dynamic>> entries) => {
        'id': 10,
        'dateTime': '2026-06-01T12:00:00.000Z',
        'mealType': 'LUNCH',
        'name': null,
        'entries': entries,
        'updatedAt': '2026-06-01T12:00:00.000Z',
        'deletedAt': null,
      };

  test('a tagged entry gets the local client id of its recipe; an untagged one stays untagged', () async {
    await seedFood('food-1', 1);
    await seedFood('food-2', 2);
    await seedRecipe('recipe-local', 7);
    adapter.meals = [
      meal([_entry(1, 100, recipeId: 7, recipeName: 'Chilli'), _entry(2, 50)]),
    ];

    await pull.pullAll();

    final entries = await db.select(db.mealEntries).get();
    expect(entries.firstWhere((e) => e.foodClientId == 'food-1').recipeClientId, 'recipe-local');
    expect(entries.firstWhere((e) => e.foodClientId == 'food-2').recipeClientId, isNull);
  });

  test('a recipe this device does not know leaves the entry untagged and the meal in', () async {
    await seedFood('food-1', 1);
    adapter.meals = [
      meal([_entry(1, 100, recipeId: 99, recipeName: 'Gone')]),
    ];

    await pull.pullAll();

    final entries = await db.select(db.mealEntries).get();
    expect(entries.single.recipeClientId, isNull);
    expect(await db.select(db.meals).get(), hasLength(1));
  });

  test('a later pull replaces the entries together with their tags', () async {
    await seedFood('food-1', 1);
    await seedRecipe('recipe-local', 7);
    adapter.meals = [
      meal([_entry(1, 100, recipeId: 7)]),
    ];
    await pull.pullAll();

    adapter.meals = [
      meal([_entry(1, 100)]),
    ];
    await pull.pullAll();

    expect((await db.select(db.mealEntries).get()).single.recipeClientId, isNull);
  });
}
