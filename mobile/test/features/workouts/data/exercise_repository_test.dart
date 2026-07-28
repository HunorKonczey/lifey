import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/exercise_repository.dart';

/// [ExerciseRepository.getOrCreateByName] backs the standalone-session
/// processor's generic placeholder exercise (docs/watch/
/// 44-watch-f6-standalone-plan.md D-F6.3) — it must resolve to the same
/// exercise on every synced session, not create a duplicate each time.
void main() {
  late AppDatabase db;
  late ExerciseRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ExerciseRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  test('create returns the new clientId', () async {
    final clientId = await repo.create('Bench Press');

    expect(clientId, isNotEmpty);
    final row = await db.select(db.exercises).getSingle();
    expect(row.clientId, clientId);
    expect(row.name, 'Bench Press');
  });

  test('getOrCreateByName creates one exercise on first call, reuses it on the next', () async {
    final firstId = await repo.getOrCreateByName('Gyors erőedzés');
    final secondId = await repo.getOrCreateByName('Gyors erőedzés');

    expect(secondId, firstId);
    final rows = await db.select(db.exercises).get();
    expect(rows, hasLength(1));
  });

  test('getOrCreateByName finds a pre-existing exercise without creating a duplicate', () async {
    final createdId = await repo.create('Gyors erőedzés');

    final resolvedId = await repo.getOrCreateByName('Gyors erőedzés');

    expect(resolvedId, createdId);
    final rows = await db.select(db.exercises).get();
    expect(rows, hasLength(1));
  });

  test('getOrCreateByName does not match a different name', () async {
    await repo.create('Gyors erőedzés');

    final otherId = await repo.getOrCreateByName('Push day');

    final rows = await db.select(db.exercises).get();
    expect(rows, hasLength(2));
    expect(rows.map((r) => r.clientId), contains(otherId));
  });
}

/// Prevents OutboxWriter's fire-and-forget kick from touching the network —
/// same pattern as workout_session_repository_update_test.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}
