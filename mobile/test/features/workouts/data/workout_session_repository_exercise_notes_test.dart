import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';

/// LIF-224: a comment per exercise per session. It has to reach the backend
/// with the planned exercise, survive a local read, and seed the next
/// session's comment through [WorkoutSessionRepository.getPreviousExerciseNotes].
void main() {
  late AppDatabase db;
  late WorkoutSessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<List<Map<String, dynamic>>> lastPlanned(String operation) async {
    final ops = await (db.select(db.pendingOperations)..where((t) => t.operation.equals(operation))).get();
    final payload = jsonDecode(ops.last.payloadJson) as Map<String, dynamic>;
    return (payload['plannedExercises'] as List).cast<Map<String, dynamic>>();
  }

  Future<String> session(DateTime startedAt, Map<String, String?> notes) => repo.create(
        startedAt: startedAt,
        exercises: [
          for (final entry in notes.entries) PlannedExerciseInput(exerciseClientId: entry.key, note: entry.value),
        ],
        sets: const [],
      );

  group('payload and local storage', () {
    test('create sends each note trimmed and omits a blank one', () async {
      await session(DateTime.utc(2026, 11, 20, 17), {'ex-bench': '  seat on 4 ', 'ex-squat': '   ', 'ex-row': null});

      final planned = await lastPlanned('create');
      expect(planned[0]['note'], 'seat on 4');
      expect(planned[1].containsKey('note'), isFalse);
      expect(planned[2].containsKey('note'), isFalse);
    });

    test('the note comes back on the session read from the local DB', () async {
      final clientId = await session(DateTime.utc(2026, 11, 20, 17), {'ex-bench': 'seat on 4', 'ex-squat': ''});

      final stored = await repo.findByClientId(clientId);
      expect({for (final e in stored!.exercises) e.exerciseClientId: e.note}, {'ex-bench': 'seat on 4', 'ex-squat': null});
    });

    test('rate re-sends the stored notes rather than dropping them', () async {
      final clientId = await session(DateTime.utc(2026, 11, 20, 17), {'ex-bench': 'seat on 4'});

      await repo.rate(clientId, rpe: 8);

      final planned = await lastPlanned('update');
      expect(planned.single['note'], 'seat on 4');
    });
  });

  group('getPreviousExerciseNotes', () {
    test('takes each exercise\'s note from its most recent session', () async {
      await session(DateTime.utc(2026, 11, 10, 17), {'ex-bench': 'seat on 3', 'ex-squat': 'belt'});
      await session(DateTime.utc(2026, 11, 17, 17), {'ex-bench': 'seat on 4'});

      final notes = await repo.getPreviousExerciseNotes(['ex-bench', 'ex-squat', 'ex-row']);

      expect(notes, {'ex-bench': 'seat on 4', 'ex-squat': 'belt'});
    });

    test('a note cleared in the latest session stays cleared', () async {
      await session(DateTime.utc(2026, 11, 10, 17), {'ex-bench': 'seat on 3'});
      await session(DateTime.utc(2026, 11, 17, 17), {'ex-bench': null});

      expect(await repo.getPreviousExerciseNotes(['ex-bench']), isEmpty);
    });

    test('never reads the session being edited', () async {
      await session(DateTime.utc(2026, 11, 10, 17), {'ex-bench': 'seat on 3'});
      final current = await session(DateTime.utc(2026, 11, 17, 17), {'ex-bench': 'seat on 4'});

      final notes = await repo.getPreviousExerciseNotes(['ex-bench'], excludeSessionClientId: current);

      expect(notes, {'ex-bench': 'seat on 3'});
    });

    test('skips a trainer-scheduled session that has not started yet', () async {
      await session(DateTime.utc(2026, 11, 10, 17), {'ex-bench': 'seat on 3'});
      await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
            clientId: 'upcoming',
            scheduledFor: Value(DateTime.utc(2026, 11, 30)),
          ));
      await db.into(db.workoutSessionExercises).insert(WorkoutSessionExercisesCompanion.insert(
            clientId: 'upcoming-link',
            sessionClientId: 'upcoming',
            exerciseClientId: 'ex-bench',
          ));

      expect(await repo.getPreviousExerciseNotes(['ex-bench']), {'ex-bench': 'seat on 3'});
    });

    test('no exercises asked, no query', () async {
      expect(await repo.getPreviousExerciseNotes(const []), isEmpty);
    });
  });
}

/// Swallows the outbox's `_kick()` so no HTTP is attempted.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}
