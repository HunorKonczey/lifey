import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/client_ref.dart';
import '../../../core/sync/outbox_writer.dart';
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

  Stream<List<Recipe>> watchAll() {
    return _db.select(_db.recipes).watch().asyncMap((recipeRows) async {
      if (recipeRows.isEmpty) return const <Recipe>[];

      final foods = {for (final f in await _db.select(_db.foods).get()) f.clientId: f};

      final ingredientsByRecipe = <String, List<RecipeIngredient>>{};
      for (final ing in await _db.select(_db.recipeIngredients).get()) {
        final food = foods[ing.foodClientId];
        final grams = ing.quantityInGrams;
        ingredientsByRecipe.putIfAbsent(ing.recipeClientId, () => []).add(
              RecipeIngredient(
                foodClientId: ing.foodClientId,
                foodName: food?.name ?? 'Unknown',
                quantityInGrams: grams,
                calories: (food?.caloriesPer100g ?? 0) * grams / 100,
                protein: (food?.proteinPer100g ?? 0) * grams / 100,
              ),
            );
      }

      final recipes = recipeRows
          .map((row) => _toDomain(row, ingredientsByRecipe[row.clientId] ?? const []))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return recipes;
    });
  }

  Future<void> create({
    required String name,
    String? description,
    required List<RecipeIngredientInput> ingredients,
  }) async {
    final clientId = newClientId();
    await _db.transaction(() async {
      await _db.into(_db.recipes).insert(
            RecipesCompanion.insert(
              clientId: clientId,
              name: name,
              description: Value(description),
            ),
          );
      await _insertIngredients(clientId, ingredients);
    });
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: 'recipe',
      payload: _payload(name: name, description: description, ingredients: ingredients),
    );
  }

  Future<void> update(
    String clientId, {
    required String name,
    String? description,
    required List<RecipeIngredientInput> ingredients,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.recipes)..where((t) => t.clientId.equals(clientId))).write(
        RecipesCompanion(name: Value(name), description: Value(description)),
      );
      await (_db.delete(_db.recipeIngredients)..where((t) => t.recipeClientId.equals(clientId)))
          .go();
      await _insertIngredients(clientId, ingredients);
    });
    await _outbox.enqueueUpdate(
      clientId: clientId,
      entityType: 'recipe',
      payload: _payload(name: name, description: description, ingredients: ingredients),
    );
  }

  Future<void> delete(String clientId) async {
    // Must enqueue before the local row is gone — enqueueDelete needs to
    // read its serverId while the row still exists.
    await _outbox.enqueueDelete(clientId: clientId, entityType: 'recipe');
    await _db.transaction(() async {
      await (_db.delete(_db.recipeIngredients)..where((t) => t.recipeClientId.equals(clientId)))
          .go();
      await (_db.delete(_db.recipes)..where((t) => t.clientId.equals(clientId))).go();
    });
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
    required List<RecipeIngredientInput> ingredients,
  }) {
    return {
      'name': name,
      'description': description,
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
      ingredients: ingredients,
    );
  }
}

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});
