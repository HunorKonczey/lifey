import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/pending_delete_filter.dart';
import '../../../core/utils/combine_latest.dart';
import '../domain/food.dart';

/// Local-first access to the shared food catalog.
class FoodRepository {
  FoodRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  Stream<List<Food>> watchAll() {
    final foods$ = (_db.select(_db.foods)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
    final pendingOps$ = _db.select(_db.pendingOperations).watch();
    return combineLatest2(foods$, pendingOps$, (rows, ops) {
      final blocked = blockedByActiveDelete(ops);
      return rows.where((r) => !blocked.contains(r.clientId)).map(_toDomain).toList();
    });
  }

  /// Like [watchAll] but bounded to the first [limit] foods (by name). The
  /// pending-delete filter can drop rows below the SQL LIMIT, so callers that
  /// need to know whether more rows exist beyond [limit] should request
  /// `limit + 1` and treat a returned list longer than the intended page size
  /// as "more available".
  Stream<List<Food>> watchPaged({required int limit}) {
    final foods$ = (_db.select(_db.foods)
          ..orderBy([(t) => OrderingTerm.asc(t.name)])
          ..limit(limit))
        .watch();
    final pendingOps$ = _db.select(_db.pendingOperations).watch();
    return combineLatest2(foods$, pendingOps$, (rows, ops) {
      final blocked = blockedByActiveDelete(ops);
      return rows.where((r) => !blocked.contains(r.clientId)).map(_toDomain).toList();
    });
  }

  Future<void> create({
    required String name,
    required double calories,
    required double protein,
    double? carbs,
    double? fat,
    String? barcode,
  }) async {
    final clientId = newClientId();
    await _db.into(_db.foods).insert(FoodsCompanion.insert(
          clientId: clientId,
          name: name,
          caloriesPer100g: calories,
          proteinPer100g: protein,
          carbsPer100g: Value(carbs),
          fatPer100g: Value(fat),
          barcode: Value(barcode),
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
        'barcode': barcode,
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
    String? barcode,
  }) async {
    await (_db.update(_db.foods)..where((t) => t.clientId.equals(clientId))).write(
      FoodsCompanion(
        name: Value(name),
        caloriesPer100g: Value(calories),
        proteinPer100g: Value(protein),
        carbsPer100g: Value(carbs),
        fatPer100g: Value(fat),
        barcode: Value(barcode),
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
        'barcode': barcode,
      },
    );
  }

  Future<void> delete(String clientId) async {
    // Must enqueue before the local row is gone — enqueueDelete needs to
    // read its serverId while the row still exists. If it queued a server
    // delete, the row stays (hidden by the controller's filter) until that
    // delete is confirmed — see EntitySyncConfig.cleanupChildren's doc.
    final queued = await _outbox.enqueueDelete(clientId: clientId, entityType: 'food');
    if (!queued) {
      await (_db.delete(_db.foods)..where((t) => t.clientId.equals(clientId))).go();
    }
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
      barcode: row.barcode,
    );
  }
}

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return FoodRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});
