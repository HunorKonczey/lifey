import 'package:drift/drift.dart';

/// Local cache of the shared food catalog.
@DataClassName('FoodRow')
class Foods extends Table {
  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  RealColumn get caloriesPer100g => real()();
  RealColumn get proteinPer100g => real()();
  RealColumn get carbsPer100g => real().nullable()();
  RealColumn get fatPer100g => real().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}
