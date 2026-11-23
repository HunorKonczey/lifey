import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';

/// docs/integrations/89 G1.3 (D-G2, D-G3): an imported session's provenance
/// (`importSource` / `importAppName`) goes out on create and is stored
/// locally. A Lifey-recorded session's payload stays exactly as it was
/// before imports existed, and an update never re-sends provenance.
void main() {
  late AppDatabase db;
  late WorkoutSessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<Map<String, dynamic>> lastPayload(String operation) async {
    final ops = await (db.select(db.pendingOperations)
          ..where((t) => t.operation.equals(operation)))
        .get();
    return jsonDecode(ops.last.payloadJson) as Map<String, dynamic>;
  }

  Future<String> createImportedRun() => repo.create(
        startedAt: DateTime.utc(2026, 11, 20, 6),
        finishedAt: DateTime.utc(2026, 11, 20, 6, 42),
        exercises: const [],
        sets: const [],
        activeCalories: 512,
        averageHeartRate: 148,
        healthWorkoutId: 'hc-run-1',
        importSource: 'HEALTH',
        importAppName: 'Garmin Connect',
        sessionKind: 'CARDIO',
        activityType: 'RUNNING',
        movingSeconds: 2520,
      );

  test('create of an imported session sends its provenance with the dedupe key', () async {
    await createImportedRun();

    final payload = await lastPayload('create');
    expect(payload['importSource'], 'HEALTH');
    expect(payload['importAppName'], 'Garmin Connect');
    expect(payload['healthWorkoutId'], 'hc-run-1');
  });

  test('an imported session reads back as imported, not as watch-enriched', () async {
    final clientId = await createImportedRun();

    final session = (await repo.findByClientId(clientId))!;
    expect(session.importSource, 'HEALTH');
    expect(session.importAppName, 'Garmin Connect');
    expect(session.isImported, isTrue);
    // It has a healthWorkoutId, but Lifey's watch never touched it, so it must not
    // get the watch chip (docs/integrations/89 G1.7 gives it a source chip instead).
    expect(session.enrichedFromWatch, isFalse);
  });

  test('a Lifey-recorded session sends no provenance keys at all', () async {
    await repo.create(
      startedAt: DateTime.utc(2026, 11, 20, 17),
      exercises: const [],
      sets: const [],
      healthWorkoutId: 'hk-paired',
    );

    final payload = await lastPayload('create');
    expect(payload.containsKey('importSource'), isFalse);
    expect(payload.containsKey('importAppName'), isFalse);
  });

  test('a session paired by the watch is still watch-enriched and not imported', () async {
    final clientId = await repo.create(
      startedAt: DateTime.utc(2026, 11, 20, 17),
      exercises: const [],
      sets: const [],
      healthWorkoutId: 'hk-paired',
    );

    final session = (await repo.findByClientId(clientId))!;
    expect(session.isImported, isFalse);
    expect(session.enrichedFromWatch, isTrue);
  });

  test('an update keeps the stored provenance and never re-sends it', () async {
    final clientId = await createImportedRun();

    // The user corrects the activity type (D-G6 allows that on an import).
    await repo.update(
      clientId,
      startedAt: DateTime.utc(2026, 11, 20, 6),
      finishedAt: DateTime.utc(2026, 11, 20, 6, 42),
      exercises: const [],
      sets: const [],
      activityType: const Value('WALKING'),
    );

    final session = (await repo.findByClientId(clientId))!;
    expect(session.activityType, 'WALKING');
    expect(session.importSource, 'HEALTH');
    expect(session.importAppName, 'Garmin Connect');

    final ops = await db.select(db.pendingOperations).get();
    for (final op in ops.where((o) => o.operation != 'create')) {
      final payload = jsonDecode(op.payloadJson) as Map<String, dynamic>;
      expect(payload.containsKey('importSource'), isFalse);
      expect(payload.containsKey('importAppName'), isFalse);
    }
  });
}

/// Swallows the outbox's `_kick()` so no HTTP is attempted.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}
