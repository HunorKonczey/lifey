import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/nutrition/data/food_repository.dart';

/// A deleted food stays in the table until the server confirms the delete. With the backend letting a deleted
/// food release its barcode (V82), the food that replaces it shares that barcode for a moment: the lookup must
/// answer with the live one, and must not fail for finding two rows.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}

void main() {
  late AppDatabase db;
  late FoodRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    repo = FoodRepository(db, OutboxWriter(db, _NoopSyncEngine(db, dio)));
  });

  tearDown(() => db.close());

  Future<String> syncedFood(String name, String barcode, int serverId) async {
    final clientId = await repo.create(name: name, calories: 60, protein: 3, barcode: barcode);
    await db.customStatement('UPDATE foods SET server_id = ? WHERE client_id = ?', [serverId, clientId]);
    return clientId;
  }

  test('finds the food that has the barcode', () async {
    final id = await repo.create(name: 'Milk', calories: 60, protein: 3, barcode: '123');

    final found = await repo.findByBarcode('123');

    expect(found?.clientId, id);
  });

  test('a food with a delete in flight is not found by its barcode', () async {
    final old = await syncedFood('Milk', '123', 5);
    await repo.delete(old);

    expect(await repo.findByBarcode('123'), isNull);
  });

  test('the replacement is found, and the deleted twin does not break the lookup', () async {
    final old = await syncedFood('Milk', '123', 5);
    await repo.delete(old);
    final replacement = await repo.create(name: 'Milk 2', calories: 60, protein: 3, barcode: '123');

    final found = await repo.findByBarcode('123');

    expect(found?.clientId, replacement);
  });

  test('an unknown barcode is null', () async {
    expect(await repo.findByBarcode('nope'), isNull);
  });
}
