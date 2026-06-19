import 'package:drift/drift.dart';

import 'food_table.dart';

@DataClassName('MealRow')
class Meals extends Table {
  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  DateTimeColumn get dateTime => dateTime()();
  TextColumn get mealType => text()(); // BREAKFAST / LUNCH / DINNER / SNACK

  @override
  Set<Column> get primaryKey => {clientId};
}

@DataClassName('MealEntryRow')
class MealEntries extends Table {
  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get mealClientId => text().references(Meals, #clientId)();
  TextColumn get foodClientId => text().references(Foods, #clientId)();
  RealColumn get quantityInGrams => real()();

  @override
  Set<Column> get primaryKey => {clientId};
}
