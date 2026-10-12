import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/exercise_repository.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';
import 'package:lifey/features/workouts/domain/exercise_enums.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// The windowed reads behind the Exercises and Sessions tabs (docs/14-pagination-plan.md Phase 1.3, LIF-113).
void main() {
  late AppDatabase db;
  late ExerciseRepository exercises;
  late WorkoutSessionRepository sessions;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final outbox = OutboxWriter(db, _NoopSyncEngine(db, Dio()));
    exercises = ExerciseRepository(db, outbox);
    sessions = WorkoutSessionRepository(db, outbox);
  });

  tearDown(() => db.close());

  group('ExerciseRepository.watchPaged', () {
    test('without a category the window runs muscle group by muscle group, then by name', () async {
      // Created in an order that is neither the group order nor alphabetical.
      await exercises.create('Squat', category: 'LEGS');
      await exercises.create('Row', category: 'BACK');
      await exercises.create('Zottman curl', category: 'BICEPS');
      await exercises.create('Bench press', category: 'CHEST');
      await exercises.create('Fly', category: 'CHEST');
      await exercises.create('Yoga flow'); // no group - sorts after every known one

      final all = await exercises.watchPaged(limit: 100).first;

      expect(all.map((e) => e.name), ['Bench press', 'Fly', 'Row', 'Zottman curl', 'Squat', 'Yoga flow']);
      expect(kMuscleGroups.indexOf('CHEST'), lessThan(kMuscleGroups.indexOf('BACK')));
    });

    test('the limit cuts the window mid-order, not alphabetically across groups', () async {
      await exercises.create('Squat', category: 'LEGS');
      await exercises.create('Row', category: 'BACK');
      await exercises.create('Bench press', category: 'CHEST');
      await exercises.create('Fly', category: 'CHEST');

      final window = await exercises.watchPaged(limit: 3).first;

      expect(window.map((e) => e.name), ['Bench press', 'Fly', 'Row']);
    });

    test('a category narrows it to that group, by name', () async {
      await exercises.create('Row', category: 'BACK');
      await exercises.create('Pull-up', category: 'BACK');
      await exercises.create('Bench press', category: 'CHEST');

      final back = await exercises.watchPaged(limit: 100, category: 'BACK').first;

      expect(back.map((e) => e.name), ['Pull-up', 'Row']);
    });

    test('an exercise with a delete queued is left out', () async {
      final id = await exercises.create('Row', category: 'BACK');
      await exercises.create('Pull-up', category: 'BACK');
      await exercises.delete(id);

      final window = await exercises.watchPaged(limit: 100).first;

      expect(window.map((e) => e.name), ['Pull-up']);
    });
  });

  group('WorkoutSessionRepository.watchPaged', () {
    Future<String> started(DateTime at, {String exerciseId = 'ex-a', int sets = 1}) => sessions.create(
          startedAt: at,
          finishedAt: at.add(const Duration(hours: 1)),
          exercises: [PlannedExerciseInput(exerciseClientId: exerciseId, targetSets: sets)],
          sets: [
            for (var i = 0; i < sets; i++)
              ExerciseSetInput(exerciseClientId: exerciseId, reps: 8 + i, weight: 50, performedAt: at.add(Duration(minutes: i))),
          ],
        );

    Future<void> upcoming(String clientId, DateTime scheduledFor) =>
        db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(clientId: clientId, scheduledFor: Value(scheduledFor)));

    test('holds the newest started sessions only, newest first', () async {
      for (var day = 1; day <= 5; day++) {
        await started(DateTime.utc(2026, 7, day, 17));
      }

      final window = await sessions.watchPaged(limit: 3).first;

      expect(window.map((s) => s.startedAt!.day), [5, 4, 3]);
    });

    test('every upcoming session comes with the window, however small it is', () async {
      for (var day = 1; day <= 5; day++) {
        await started(DateTime.utc(2026, 7, day, 17));
      }
      await upcoming('plan-1', DateTime.utc(2026, 8, 1));
      await upcoming('plan-2', DateTime.utc(2026, 8, 2));

      final window = await sessions.watchPaged(limit: 2).first;

      expect(window.where((s) => s.startedAt == null).map((s) => s.clientId), unorderedEquals(['plan-1', 'plan-2']));
      expect(window.where((s) => s.startedAt != null), hasLength(2));
    });

    test('a window session is built exactly as watchAll builds it - sets, plan and order', () async {
      final older = await started(DateTime.utc(2026, 7, 1, 17), exerciseId: 'ex-a', sets: 3);
      final newer = await started(DateTime.utc(2026, 7, 2, 17), exerciseId: 'ex-b', sets: 2);
      await started(DateTime.utc(2026, 6, 1, 17), exerciseId: 'ex-c', sets: 4); // outside the window

      final full = {for (final s in await sessions.watchAll().first) s.clientId: s};
      final window = await sessions.watchPaged(limit: 2).first;

      expect(window.map((s) => s.clientId), [newer, older]);
      for (final s in window) {
        final expected = full[s.clientId]!;
        expect(s.sets.map((x) => (x.exerciseClientId, x.reps, x.weight)), expected.sets.map((x) => (x.exerciseClientId, x.reps, x.weight)));
        expect(s.exercises.map((x) => (x.exerciseClientId, x.targetSets)), expected.exercises.map((x) => (x.exerciseClientId, x.targetSets)));
      }
    });

    test('the sets of sessions outside the window are not carried along', () async {
      await started(DateTime.utc(2026, 7, 2, 17), sets: 2);
      await started(DateTime.utc(2026, 6, 1, 17), sets: 4);

      final window = await sessions.watchPaged(limit: 1).first;

      expect(window, hasLength(1));
      expect(window.single.sets, hasLength(2));
    });

    test('a session with a delete queued is left out', () async {
      final gone = await started(DateTime.utc(2026, 7, 2, 17));
      final kept = await started(DateTime.utc(2026, 7, 1, 17));
      await sessions.delete(gone);

      final window = await sessions.watchPaged(limit: 10).first;

      expect(window.map((s) => s.clientId), [kept]);
    });

    test('an empty database gives an empty window', () async {
      expect(await sessions.watchPaged(limit: 5).first, <WorkoutSession>[]);
    });
  });

  group('WorkoutSessionRepository.watchSummaries', () {
    Future<String> logged(DateTime at, {int sets = 3}) => sessions.create(
          startedAt: at,
          finishedAt: at.add(const Duration(hours: 1)),
          exercises: [const PlannedExerciseInput(exerciseClientId: 'ex-a', targetSets: 3)],
          sets: [
            for (var i = 0; i < sets; i++)
              ExerciseSetInput(exerciseClientId: 'ex-a', reps: 8, weight: 50, performedAt: at.add(Duration(minutes: i))),
          ],
        );

    test('holds every session, newest first - not a window', () async {
      for (var day = 1; day <= 60; day++) {
        await logged(DateTime.utc(2026, 1, 1).add(Duration(days: day)), sets: 1);
      }

      final summaries = await sessions.watchSummaries().first;

      expect(summaries, hasLength(60));
      expect(summaries.first.startedAt!.isAfter(summaries.last.startedAt!), isTrue);
    });

    test('carries no children: no sets, no planned exercises', () async {
      await logged(DateTime.utc(2026, 7, 2, 17));

      final summary = (await sessions.watchSummaries().first).single;
      final full = (await sessions.watchAll().first).single;

      expect(full.sets, hasLength(3));
      expect(full.exercises, hasLength(1));
      expect(summary.sets, isEmpty);
      expect(summary.exercises, isEmpty);
    });

    test('has everything else watchAll has: the session fields and the cardio metrics', () async {
      final at = DateTime.utc(2026, 7, 3, 7);
      final cardioId = await sessions.create(
        startedAt: at,
        finishedAt: at.add(const Duration(minutes: 40)),
        exercises: const [],
        sets: const [],
        sessionKind: 'CARDIO',
        activityType: 'RUNNING',
        movingSeconds: 2400,
        cardio: const CardioMetrics(distanceMeters: 8000, maxHeartRate: 171),
      );
      await logged(DateTime.utc(2026, 7, 2, 17));

      final full = {for (final s in await sessions.watchAll().first) s.clientId: s};
      final summaries = await sessions.watchSummaries().first;

      expect(summaries.map((s) => s.clientId), (await sessions.watchAll().first).map((s) => s.clientId));
      for (final s in summaries) {
        final f = full[s.clientId]!;
        expect(s.startedAt, f.startedAt);
        expect(s.finishedAt, f.finishedAt);
        expect(s.sessionKind, f.sessionKind);
        expect(s.activityType, f.activityType);
        expect(s.movingSeconds, f.movingSeconds);
        expect(s.cardio?.distanceMeters, f.cardio?.distanceMeters);
        expect(s.cardio?.maxHeartRate, f.cardio?.maxHeartRate);
      }
      expect(summaries.firstWhere((s) => s.clientId == cardioId).cardio?.distanceMeters, 8000);
    });

    test('upcoming sessions are in, and a session with a delete queued is out', () async {
      await db.into(db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(clientId: 'plan-1', scheduledFor: Value(DateTime.utc(2026, 8, 1))),
          );
      final gone = await logged(DateTime.utc(2026, 7, 2, 17));
      final kept = await logged(DateTime.utc(2026, 7, 1, 17));
      await sessions.delete(gone);

      final summaries = await sessions.watchSummaries().first;

      expect(summaries.map((s) => s.clientId), unorderedEquals(['plan-1', kept]));
    });

    test('an empty database gives an empty list', () async {
      expect(await sessions.watchSummaries().first, <WorkoutSession>[]);
    });
  });
}

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}
