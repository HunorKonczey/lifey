import 'package:drift/drift.dart';

import 'food_table.dart';

@DataClassName('MealRow')
class Meals extends Table {
  @override
  String get tableName => 'meals';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  // Named mealDateTime, not dateTime — that name collides with Table's own
  // dateTime() column builder method.
  DateTimeColumn get mealDateTime => dateTime()();
  TextColumn get mealType => text()(); // BREAKFAST / LUNCH / DINNER / SNACK
  TextColumn get name => text().nullable()();

  /// The trainer's single editable comment on this meal (LIF-144); null when uncommented. Server-owned — this app
  /// never sends it (the meal payloads carry only the fields above), it only arrives with a pull.
  TextColumn get trainerComment => text().nullable()();

  /// When [trainerComment] was last written; null when uncommented.
  DateTimeColumn get trainerCommentAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}

@DataClassName('MealEntryRow')
class MealEntries extends Table {
  @override
  String get tableName => 'meal_entries';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get mealClientId => text().references(Meals, #clientId)();
  TextColumn get foodClientId => text().references(Foods, #clientId)();
  RealColumn get quantityInGrams => real()();

  @override
  Set<Column> get primaryKey => {clientId};
}
