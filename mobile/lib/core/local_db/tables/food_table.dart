import 'package:drift/drift.dart';

/// Local cache of the shared food catalog.
@DataClassName('FoodRow')
class Foods extends Table {
  @override
  String get tableName => 'foods';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();
  RealColumn get caloriesPer100g => real()();
  RealColumn get proteinPer100g => real()();
  RealColumn get carbsPer100g => real().nullable()();
  RealColumn get fatPer100g => real().nullable()();
  TextColumn get barcode => text().nullable()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();

  /// Non-null only for a trainer-assigned copy (docs/personal_trainer/05-mobil-terv.md
  /// §2) — the trainer's server-side user id, drives the "Edzőtől" badge.
  IntColumn get originTrainerId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}
