import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/nutrition/data/meal_repository.dart';
import 'package:lifey/features/nutrition/domain/recipe_usage.dart';
import 'package:lifey/features/recipes/domain/recipe.dart';

/// docs/88: a recipe is used once per meal that has an entry tagged with it - not once per entry - and only within the
/// last 90 days, whichever way the meal was built.
void main() {
  late AppDatabase db;
  late MealRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = MealRepository(db, OutboxWriter(db, SyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<void> meal(String id, DateTime at, List<String?> recipeTags) async {
    await db.into(db.meals).insert(MealsCompanion.insert(clientId: id, mealDateTime: at, mealType: 'LUNCH'));
    for (final (i, tag) in recipeTags.indexed) {
      await db.into(db.mealEntries).insert(MealEntriesCompanion.insert(
            clientId: '$id-e$i',
            mealClientId: id,
            foodClientId: 'food',
            quantityInGrams: 100,
            recipeClientId: Value(tag),
          ));
    }
  }

  // The database keeps whole seconds.
  final now = DateTime.fromMillisecondsSinceEpoch(DateTime.now().millisecondsSinceEpoch ~/ 1000 * 1000);

  test('a meal is one use of a recipe however many of its entries carry the tag', () async {
    await meal('m1', now.subtract(const Duration(days: 2)), ['chilli', 'chilli', 'chilli', null]);

    final usage = await repo.watchRecipeUsage().first;

    expect(usage.keys, ['chilli']);
    expect(usage['chilli']!.useCount, 1);
  });

  test('two recipes in one meal are one use each; a second meal is a second use and sets the last-used date', () async {
    final earlier = now.subtract(const Duration(days: 5));
    final later = now.subtract(const Duration(days: 1));
    await meal('m1', earlier, ['chilli', 'soup']);
    await meal('m2', later, ['chilli']);

    final usage = await repo.watchRecipeUsage().first;

    expect(usage['chilli']!.useCount, 2);
    expect(usage['chilli']!.lastUsedAt, later);
    expect(usage['soup']!.useCount, 1);
    expect(usage['soup']!.lastUsedAt, earlier);
  });

  test('entries without a tag are not a use of anything', () async {
    await meal('m1', now, [null, null]);

    expect(await repo.watchRecipeUsage().first, isEmpty);
  });

  test('a meal older than 90 days does not count', () async {
    await meal('old', now.subtract(const Duration(days: 120)), ['chilli']);
    await meal('recent', now.subtract(const Duration(days: 3)), ['soup']);

    final usage = await repo.watchRecipeUsage().first;

    expect(usage.keys, ['soup']);
  });

  group('rankRecipesByUsage', () {
    Recipe recipe(String id, {bool favorite = false}) => Recipe(clientId: id, name: id, favorite: favorite, ingredients: const []);
    int byName(Recipe a, Recipe b) => a.name.compareTo(b.name);

    test('recents first (newest first), then favourites, then the rest, each group A to Z', () {
      final recipes = [recipe('d'), recipe('c', favorite: true), recipe('b'), recipe('a', favorite: true), recipe('e')];
      final usage = {
        'd': RecipeUsage(lastUsedAt: DateTime(2026, 10, 1), useCount: 1),
        'e': RecipeUsage(lastUsedAt: DateTime(2026, 10, 9), useCount: 4),
      };

      final ranked = rankRecipesByUsage(recipes, usage, byName: byName);

      expect(ranked.map((r) => r.clientId), ['e', 'd', 'a', 'c', 'b']);
    });

    test('a recent favourite is listed once, among the recents', () {
      final recipes = [recipe('a', favorite: true), recipe('b')];
      final usage = {'a': RecipeUsage(lastUsedAt: DateTime(2026, 10, 1), useCount: 1)};

      expect(rankRecipesByUsage(recipes, usage, byName: byName).map((r) => r.clientId), ['a', 'b']);
    });

    test('only the six most recent lead; the others fall back to favourites and A to Z', () {
      final recipes = [for (final c in 'abcdefgh'.split('')) recipe(c)];
      final usage = {
        for (final (i, c) in 'abcdefgh'.split('').indexed) c: RecipeUsage(lastUsedAt: DateTime(2026, 10, 1 + i), useCount: 1),
      };

      final ranked = rankRecipesByUsage(recipes, usage, byName: byName).map((r) => r.clientId).toList();

      // h, g, f, e, d, c are the six newest; a and b are older and follow A to Z.
      expect(ranked, ['h', 'g', 'f', 'e', 'd', 'c', 'a', 'b']);
    });

    test('without any usage it is favourites first, then A to Z', () {
      final recipes = [recipe('b'), recipe('c', favorite: true), recipe('a')];

      expect(rankRecipesByUsage(recipes, const {}, byName: byName).map((r) => r.clientId), ['c', 'a', 'b']);
    });
  });
}
