import 'package:drift/drift.dart';

import 'food_table.dart';

@DataClassName('RecipeRow')
class Recipes extends Table {
  @override
  String get tableName => 'recipes';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  IntColumn get servings => integer().withDefault(const Constant(1))();

  /// Non-null only for a trainer-assigned copy (docs/personal_trainer/05-mobil-terv.md
  /// §2) — the trainer's server-side user id, drives the "Edzőtől" badge.
  IntColumn get originTrainerId => integer().nullable()();

  /// Null if no photo is set. Mirrors the backend's `imageUpdatedAt` — the app
  /// diffs this against what it last downloaded to know when to re-fetch the
  /// recipe's photo (see RecipeImageRepository).
  DateTimeColumn get imageUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}

/// References [Recipes] and [Foods] by `clientId`, not `serverId` — the FK
/// must resolve locally even before either side has synced.
@DataClassName('RecipeIngredientRow')
class RecipeIngredients extends Table {
  @override
  String get tableName => 'recipe_ingredients';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get recipeClientId => text().references(Recipes, #clientId)();
  TextColumn get foodClientId => text().references(Foods, #clientId)();
  RealColumn get quantityInGrams => real()();

  @override
  Set<Column> get primaryKey => {clientId};
}
