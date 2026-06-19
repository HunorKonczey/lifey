import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/outbox_writer.dart';
import '../domain/food.dart';

/// Local-first access to the shared food catalog.
class FoodRepository {
  FoodRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  Stream<List<Food>> watchAll() {
    return (_db.select(_db.foods)..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  Future<void> create({
    required String name,
    required double calories,
    required double protein,
    double? carbs,
    double? fat,
  }) async {
    final clientId = newClientId();
    await _db.into(_db.foods).insert(FoodsCompanion.insert(
          clientId: clientId,
          name: name,
          caloriesPer100g: calories,
          proteinPer100g: protein,
          carbsPer100g: Value(carbs),
          fatPer100g: Value(fat),
        ));
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: 'food',
      payload: {
        'name': name,
        'caloriesPer100g': calories,
        'proteinPer100g': protein,
        'carbsPer100g': carbs,
        'fatPer100g': fat,
      },
    );
  }

  Future<void> update(
    String clientId, {
    required String name,
    required double calories,
    required double protein,
    double? carbs,
    double? fat,
  }) async {
    await (_db.update(_db.foods)..where((t) => t.clientId.equals(clientId))).write(
      FoodsCompanion(
        name: Value(name),
        caloriesPer100g: Value(calories),
        proteinPer100g: Value(protein),
        carbsPer100g: Value(carbs),
        fatPer100g: Value(fat),
      ),
    );
    await _outbox.enqueueUpdate(
      clientId: clientId,
      entityType: 'food',
      payload: {
        'name': name,
        'caloriesPer100g': calories,
        'proteinPer100g': protein,
        'carbsPer100g': carbs,
        'fatPer100g': fat,
      },
    );
  }

  Future<void> delete(String clientId) async {
    await (_db.delete(_db.foods)..where((t) => t.clientId.equals(clientId))).go();
    await _outbox.enqueueDelete(clientId: clientId, entityType: 'food');
  }

  Food _toDomain(FoodRow row) {
    return Food(
      clientId: row.clientId,
      id: row.serverId,
      name: row.name,
      caloriesPer100g: row.caloriesPer100g,
      proteinPer100g: row.proteinPer100g,
      carbsPer100g: row.carbsPer100g,
      fatPer100g: row.fatPer100g,
    );
  }
}

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return FoodRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});
