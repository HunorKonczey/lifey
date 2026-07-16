import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';

/// Covers [WorkoutSessionRepository.getPrBaseline] (docs/38-personal-records-plan.md,
/// M2): the PR baseline query must span every session (template-agnostic,
/// unlike [WorkoutSessionRepository.getPreviousPerformance]) while excluding
/// the session currently being edited.
void main() {
  late AppDatabase db;
  late WorkoutSessionRepository repo;

  const benchPress = 'ex-bench-press';
  const squat = 'ex-squat';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  test('empty history yields an empty baseline', () async {
    final baseline = await repo.getPrBaseline(exerciseClientId: benchPress);

    expect(baseline.maxWeight, isNull);
    expect(baseline.bestOneRm, isNull);
    expect(baseline.maxRepsByWeight, isEmpty);
  });

  test('aggregates sets across multiple sessions and templates', () async {
    final day1 = DateTime.utc(2026, 7, 1, 9);
    final day2 = DateTime.utc(2026, 7, 8, 9);

    await repo.create(
      startedAt: day1,
      finishedAt: day1.add(const Duration(hours: 1)),
      exercises: const [PlannedExerciseInput(exerciseClientId: benchPress)],
      sets: [
        ExerciseSetInput(
            exerciseClientId: benchPress, reps: 8, weight: 80, performedAt: day1),
      ],
      templateClientId: 'template-a',
    );
    await repo.create(
      startedAt: day2,
      finishedAt: day2.add(const Duration(hours: 1)),
      exercises: const [PlannedExerciseInput(exerciseClientId: benchPress)],
      sets: [
        ExerciseSetInput(
            exerciseClientId: benchPress, reps: 5, weight: 100, performedAt: day2),
      ],
      templateClientId: 'template-b',
    );

    final baseline = await repo.getPrBaseline(exerciseClientId: benchPress);

    // Spans both templates — the PR baseline is template-agnostic.
    expect(baseline.maxWeight, 100.0);
    expect(baseline.maxRepsByWeight[80.0], 8);
    expect(baseline.maxRepsByWeight[100.0], 5);
  });

  test('excludes the given session\'s own sets from the baseline', () async {
    final day1 = DateTime.utc(2026, 7, 1, 9);

    final excludedSessionId = await repo.create(
      startedAt: day1,
      finishedAt: day1.add(const Duration(hours: 1)),
      exercises: const [PlannedExerciseInput(exerciseClientId: benchPress)],
      sets: [
        ExerciseSetInput(
            exerciseClientId: benchPress, reps: 5, weight: 120, performedAt: day1),
      ],
    );

    final baseline = await repo.getPrBaseline(
      exerciseClientId: benchPress,
      excludeSessionClientId: excludedSessionId,
    );

    expect(baseline.maxWeight, isNull);
  });

  test('only aggregates sets for the requested exercise', () async {
    final day1 = DateTime.utc(2026, 7, 1, 9);

    await repo.create(
      startedAt: day1,
      finishedAt: day1.add(const Duration(hours: 1)),
      exercises: const [
        PlannedExerciseInput(exerciseClientId: benchPress),
        PlannedExerciseInput(exerciseClientId: squat),
      ],
      sets: [
        ExerciseSetInput(
            exerciseClientId: benchPress, reps: 5, weight: 80, performedAt: day1),
        ExerciseSetInput(
            exerciseClientId: squat, reps: 5, weight: 140, performedAt: day1),
      ],
    );

    final baseline = await repo.getPrBaseline(exerciseClientId: benchPress);

    expect(baseline.maxWeight, 80.0);
  });
}

/// Prevents OutboxWriter's fire-and-forget kick from touching the network —
/// same pattern as workout_session_repository_update_test.dart.
class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}
