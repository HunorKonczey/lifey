import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/client_ref.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
import '../domain/recipe.dart';

/// One ingredient to include when creating a recipe (request side).
class RecipeIngredientInput {
  const RecipeIngredientInput({required this.foodClientId, required this.grams});

  final String foodClientId;
  final double grams;
}

/// Local-first access to recipes and their ingredients. A recipe and its
/// ingredients are always written together (see [create]/[update]), so
/// watching just the `recipes` table is enough to catch every change to the
/// whole aggregate.
class RecipeRepository {
  RecipeRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  // recipes, recipeIngredients and foods are joined into a *single* SQL
  // query so Drift re-runs them as one atomic read, instead of watching the
  // three tables separately and combining in Dart — that let delete()'s
  // removal of a recipe's ingredients and then the recipe row itself (same
  // transaction) be observed as two independent, unsynchronized stream
  // emissions: if ingredients$ updated before recipes$ did, the combined
  // snapshot could briefly show the recipe still present but with zero
  // ingredients/macros. A join can't produce that inconsistent state — see
  // meal_repository.dart's watchAll() for the full explanation.
  Stream<List<Recipe>> watchAll() {
    final joinedRecipes$ = _db.select(_db.recipes).join([
      leftOuterJoin(
          _db.recipeIngredients, _db.recipeIngredients.recipeClientId.equalsExp(_db.recipes.clientId)),
      leftOuterJoin(_db.foods, _db.foods.clientId.equalsExp(_db.recipeIngredients.foodClientId)),
    ]).watch();

    return combineLatest2(
      joinedRecipes$,
      _db.select(_db.pendingOperations).watch(),
      (rows, ops) => (rows, ops),
    ).map((pair) {
      final (joinedRows, ops) = pair;
      final blocked = blockedByActiveDelete(ops);

      final recipeRowsByClientId = <String, RecipeRow>{};
      final ingredientsByRecipe = <String, List<RecipeIngredient>>{};
      for (final row in joinedRows) {
        final recipeRow = row.readTable(_db.recipes);
        if (blocked.contains(recipeRow.clientId)) continue;
        recipeRowsByClientId[recipeRow.clientId] = recipeRow;

        final ingredientRow = row.readTableOrNull(_db.recipeIngredients);
        if (ingredientRow == null) continue; // no ingredients — left join produced no match

        final food = row.readTableOrNull(_db.foods);
        final grams = ingredientRow.quantityInGrams;
        ingredientsByRecipe.putIfAbsent(recipeRow.clientId, () => []).add(
              RecipeIngredient(
                foodClientId: ingredientRow.foodClientId,
                foodName: food?.name ?? 'Unknown',
                quantityInGrams: grams,
                calories: (food?.caloriesPer100g ?? 0) * grams / 100,
                protein: (food?.proteinPer100g ?? 0) * grams / 100,
                carbs: (food?.carbsPer100g ?? 0) * grams / 100,
                fat: (food?.fatPer100g ?? 0) * grams / 100,
              ),
            );
      }

      final recipes = recipeRowsByClientId.values
          .map((row) => _toDomain(row, ingredientsByRecipe[row.clientId] ?? const []))
          .toList()
        ..sort((a, b) {
          if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
          return a.name.compareTo(b.name);
        });
      return recipes;
    });
  }

  Future<void> create({
    required String name,
    String? description,
    bool favorite = false,
    required List<RecipeIngredientInput> ingredients,
  }) async {
    final clientId = newClientId();
    await _db.transaction(() async {
      await _db.into(_db.recipes).insert(
            RecipesCompanion.insert(
              clientId: clientId,
              name: name,
              description: Value(description),
              favorite: Value(favorite),
            ),
          );
      await _insertIngredients(clientId, ingredients);
    });
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: 'recipe',
      payload: _payload(
          name: name, description: description, favorite: favorite, ingredients: ingredients),
    );
  }

  Future<void> update(
    String clientId, {
    required String name,
    String? description,
    bool favorite = false,
    required List<RecipeIngredientInput> ingredients,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.recipes)..where((t) => t.clientId.equals(clientId))).write(
        RecipesCompanion(
            name: Value(name), description: Value(description), favorite: Value(favorite)),
      );
      await (_db.delete(_db.recipeIngredients)..where((t) => t.recipeClientId.equals(clientId)))
          .go();
      await _insertIngredients(clientId, ingredients);
    });
    await _outbox.enqueueUpdate(
      clientId: clientId,
      entityType: 'recipe',
      payload: _payload(
          name: name, description: description, favorite: favorite, ingredients: ingredients),
    );
  }

  /// Flips a recipe's favorite flag and queues a full-aggregate update —
  /// the backend's recipe PUT requires the complete payload (it validates
  /// `ingredients` as non-empty), so a favorite-only toggle can't send just
  /// `{favorite}`. The recipe's current name/description/ingredients are
  /// read back from the local cache to build that payload.
  Future<void> toggleFavorite(String clientId, bool value) async {
    await (_db.update(_db.recipes)..where((t) => t.clientId.equals(clientId)))
        .write(RecipesCompanion(favorite: Value(value)));

    final recipeRow = await (_db.select(_db.recipes)..where((t) => t.clientId.equals(clientId)))
        .getSingle();
    final ingredientRows = await (_db.select(_db.recipeIngredients)
          ..where((t) => t.recipeClientId.equals(clientId)))
        .get();

    await _outbox.enqueueUpdate(
      clientId: clientId,
      entityType: 'recipe',
      payload: _payload(
        name: recipeRow.name,
        description: recipeRow.description,
        favorite: value,
        ingredients: ingredientRows
            .map((r) => RecipeIngredientInput(foodClientId: r.foodClientId, grams: r.quantityInGrams))
            .toList(),
      ),
    );
  }

  Future<void> delete(String clientId) async {
    // Must enqueue before the local row is gone — enqueueDelete needs to
    // read its serverId while the row still exists. If it queued a server
    // delete, the recipe and its ingredients stay (hidden by the
    // controller's filter) until that delete is confirmed — see
    // EntitySyncConfig.cleanupChildren's doc.
    final queued = await _outbox.enqueueDelete(clientId: clientId, entityType: 'recipe');
    if (!queued) {
      await _db.transaction(() async {
        await (_db.delete(_db.recipeIngredients)..where((t) => t.recipeClientId.equals(clientId)))
            .go();
        await (_db.delete(_db.recipes)..where((t) => t.clientId.equals(clientId))).go();
      });
    }
  }

  Future<void> _insertIngredients(
    String recipeClientId,
    List<RecipeIngredientInput> ingredients,
  ) async {
    for (final ing in ingredients) {
      await _db.into(_db.recipeIngredients).insert(
            RecipeIngredientsCompanion.insert(
              clientId: newClientId(),
              recipeClientId: recipeClientId,
              foodClientId: ing.foodClientId,
              quantityInGrams: ing.grams,
            ),
          );
    }
  }

  Map<String, dynamic> _payload({
    required String name,
    String? description,
    required bool favorite,
    required List<RecipeIngredientInput> ingredients,
  }) {
    return {
      'name': name,
      'description': description,
      'favorite': favorite,
      'ingredients': ingredients
          .map((i) => {'foodId': clientRef(i.foodClientId), 'quantityInGrams': i.grams})
          .toList(),
    };
  }

  Recipe _toDomain(RecipeRow row, List<RecipeIngredient> ingredients) {
    return Recipe(
      clientId: row.clientId,
      id: row.serverId,
      name: row.name,
      description: row.description,
      favorite: row.favorite,
      ingredients: ingredients,
    );
  }
}

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});
