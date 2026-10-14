import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// The reads that took the place of "the whole history, whole" (LIF-156): sessions with their sets, one session whole, and the
/// session in progress.
void main() {
  late AppDatabase db;
  late WorkoutSessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<String> logged(DateTime at, {int sets = 3, bool finished = true}) => repo.create(
        startedAt: at,
        finishedAt: finished ? at.add(const Duration(hours: 1)) : null,
        exercises: [const PlannedExerciseInput(exerciseClientId: 'ex-a', targetSets: 3)],
        sets: [
          for (var i = 0; i < sets; i++)
            ExerciseSetInput(exerciseClientId: 'ex-a', reps: 8 + i, weight: 50, performedAt: at.add(Duration(minutes: i))),
        ],
      );

  group('watchWithSets', () {
    test('has the sets, in the order they were performed, and no planned exercises', () async {
      await logged(DateTime.utc(2026, 7, 2, 17));

      final session = (await repo.watchWithSets().first).single;

      expect(session.sets.map((s) => s.reps), [8, 9, 10]);
      expect(session.exercises, isEmpty);
      expect(session.splits, isEmpty);
      expect(session.waypoints, isEmpty);
    });

    test('has the cardio metrics a record is judged on', () async {
      final at = DateTime.utc(2026, 7, 3, 7);
      await repo.create(
        startedAt: at,
        finishedAt: at.add(const Duration(minutes: 40)),
        exercises: const [],
        sets: const [],
        sessionKind: 'CARDIO',
        activityType: 'RUNNING',
        movingSeconds: 2400,
        cardio: const CardioMetrics(distanceMeters: 8000),
      );

      final session = (await repo.watchWithSets().first).single;

      expect(session.cardio?.distanceMeters, 8000);
    });

    test('its sets are the ones watchAll has, session by session', () async {
      await logged(DateTime.utc(2026, 7, 1, 17), sets: 2);
      await logged(DateTime.utc(2026, 7, 2, 17), sets: 4);

      final full = {for (final s in await repo.watchAll().first) s.clientId: s};
      final withSets = await repo.watchWithSets().first;

      expect(withSets, hasLength(2));
      for (final s in withSets) {
        expect(
          s.sets.map((x) => (x.exerciseClientId, x.reps, x.weight, x.performedAt)),
          full[s.clientId]!.sets.map((x) => (x.exerciseClientId, x.reps, x.weight, x.performedAt)),
        );
      }
    });

    test('a session with a delete queued is left out', () async {
      final gone = await logged(DateTime.utc(2026, 7, 2, 17));
      final kept = await logged(DateTime.utc(2026, 7, 1, 17));
      await repo.delete(gone);

      expect((await repo.watchWithSets().first).map((s) => s.clientId), [kept]);
    });
  });

  group('watchOne', () {
    test('is the whole session: planned exercises and sets', () async {
      final id = await logged(DateTime.utc(2026, 7, 2, 17));
      await logged(DateTime.utc(2026, 7, 1, 17), sets: 1);

      final session = await repo.watchOne(id).first;

      expect(session!.clientId, id);
      expect(session.sets, hasLength(3));
      expect(session.exercises.single.targetSets, 3);
    });

    test('is null for a session that is not there', () async {
      expect(await repo.watchOne('nope').first, isNull);
    });

    test('follows the session: a change to it is emitted, a delete of it ends in null', () async {
      final id = await logged(DateTime.utc(2026, 7, 2, 17), sets: 1);
      final emitted = <WorkoutSession?>[];
      final sub = repo.watchOne(id).listen(emitted.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(emitted.last!.sets, hasLength(1));

      await repo.rate(id, rpe: 8);
      await pumpEventQueue();
      expect(emitted.last!.rpe, 8);

      await repo.delete(id);
      await pumpEventQueue();
      expect(emitted.last, isNull);
    });
  });

  group('findActive', () {
    test('is the session that has started and not finished, whole', () async {
      await logged(DateTime.utc(2026, 7, 1, 17));
      final running = await logged(DateTime.utc(2026, 7, 2, 17), finished: false);

      final active = await repo.findActive();

      expect(active!.clientId, running);
      expect(active.exercises, hasLength(1));
      expect(active.sets, hasLength(3));
    });

    test('is the newest when more than one is running', () async {
      await logged(DateTime.utc(2026, 7, 1, 17), finished: false);
      final newer = await logged(DateTime.utc(2026, 7, 2, 17), finished: false);

      expect((await repo.findActive())!.clientId, newer);
    });

    test('with a clientId it is that session or nothing', () async {
      final a = await logged(DateTime.utc(2026, 7, 1, 17), finished: false);
      await logged(DateTime.utc(2026, 7, 2, 17), finished: false);
      final finished = await logged(DateTime.utc(2026, 7, 3, 17));

      expect((await repo.findActive(clientId: a))!.clientId, a);
      expect(await repo.findActive(clientId: finished), isNull);
      expect(await repo.findActive(clientId: 'nope'), isNull);
    });

    test('is null when nothing is running, and a running one with a delete queued does not count', () async {
      expect(await repo.findActive(), isNull);
      await logged(DateTime.utc(2026, 7, 1, 17));
      expect(await repo.findActive(), isNull);

      final running = await logged(DateTime.utc(2026, 7, 2, 17), finished: false);
      await repo.delete(running);
      expect(await repo.findActive(), isNull);
    });
  });
}

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}
