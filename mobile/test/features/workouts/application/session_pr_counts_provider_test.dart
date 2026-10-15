import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/application/session_pr_counts.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';

/// The Sessions list's record counts end to end (LIF-158): the strength ones counted by the database, the cardio ones from the
/// set-free summaries, merged into the one map the list reads.
void main() {
  late AppDatabase db;
  late WorkoutSessionRepository repo;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
    container = ProviderContainer(overrides: [workoutSessionRepositoryProvider.overrideWithValue(repo)]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  DateTime day(int d) => DateTime.utc(2026, 1, 1).add(Duration(days: d, hours: 17));

  Future<String> lift(int d, double kg) => repo.create(
        startedAt: day(d),
        finishedAt: day(d).add(const Duration(hours: 1)),
        exercises: const [],
        sets: [ExerciseSetInput(exerciseClientId: 'bench', reps: 5, weight: kg, performedAt: day(d))],
      );

  Future<String> run(int d, double meters, int seconds) => repo.create(
        startedAt: day(d),
        finishedAt: day(d).add(Duration(seconds: seconds)),
        exercises: const [],
        sets: const [],
        sessionKind: 'CARDIO',
        activityType: 'RUNNING',
        movingSeconds: seconds,
        cardio: CardioMetrics(distanceMeters: meters),
      );

  /// Keeps the provider's inputs alive and lets the streams deliver.
  Future<Map<String, int>> counts() async {
    container.listen(sessionPrCountsProvider, (previous, next) {});
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return container.read(sessionPrCountsProvider);
  }

  test('nothing logged, nothing counted', () async {
    expect(await counts(), isEmpty);
  });

  test('a strength record from the database and a cardio record from the summaries, in one map', () async {
    await lift(1, 60);
    final heavier = await lift(2, 62.5);
    await run(3, 5000, 1800);
    final longer = await run(4, 8000, 3000);

    final map = await counts();

    expect(map[heavier], 2);
    expect(map[longer], greaterThan(0));
    // The first lift and the first run set nothing: there was nothing to beat.
    expect(map.length, 2);
  });

  test('it follows a change to the history', () async {
    await lift(1, 60);
    container.listen(sessionPrCountsProvider, (previous, next) {});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(container.read(sessionPrCountsProvider), isEmpty);

    final heavier = await lift(2, 62.5);
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(container.read(sessionPrCountsProvider)[heavier], 2);
  });

  test('the cardio counts are the reference algorithm\'s, over the cardio sessions only', () async {
    await run(1, 5000, 1800);
    await run(2, 8000, 3000);
    final summaries = await repo.watchSummaries().first;

    final expected = computeSessionPrCounts([for (final s in summaries) if (s.isCardio) s]);

    expect({for (final e in (await counts()).entries) e.key: e.value}, expected);
  });
}

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}
