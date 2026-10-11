import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/application/exercise_paged_controller.dart';
import 'package:lifey/features/workouts/application/workout_sessions_paged_controller.dart';
import 'package:lifey/features/workouts/data/exercise_repository.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';

/// The windows behind the Exercises and Sessions tabs (docs/14-pagination-plan.md Phase 1.3, LIF-113): a page, "is there more",
/// and growing by a page.
void main() {
  late AppDatabase db;
  late ExerciseRepository exercises;
  late WorkoutSessionRepository sessions;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final outbox = OutboxWriter(db, _NoopSyncEngine(db, Dio()));
    exercises = ExerciseRepository(db, outbox);
    sessions = WorkoutSessionRepository(db, outbox);
    container = ProviderContainer(overrides: [
      exerciseRepositoryProvider.overrideWithValue(exercises),
      workoutSessionRepositoryProvider.overrideWithValue(sessions),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Lets the repository stream and the bridge deliver what is already in the database.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> addExercises(int count) async {
    for (var i = 0; i < count; i++) {
      // Zero-padded so name order is numeric order; one group, so the window is by name.
      await exercises.create('Exercise ${i.toString().padLeft(3, '0')}', category: 'CHEST');
    }
  }

  Future<void> addSessions(int count) async {
    for (var i = 0; i < count; i++) {
      final at = DateTime.utc(2026, 1, 1).add(Duration(days: i));
      await sessions.create(startedAt: at, finishedAt: at.add(const Duration(hours: 1)), exercises: const [], sets: const []);
    }
  }

  group('ExercisePagedController', () {
    test('a short list is shown whole and there is nothing more to load', () async {
      await addExercises(5);
      final sub = container.listen(exercisePagedControllerProvider(null), (prev, next) {});
      await settle();

      expect(sub.read().value, hasLength(5));
      expect(container.read(exercisePagedControllerProvider(null).notifier).hasMore, isFalse);
    });

    test('a long list shows one page, says there is more, and loadMore grows it by a page', () async {
      await addExercises(exercisePageSize * 2 + 10);
      final provider = exercisePagedControllerProvider(null);
      final sub = container.listen(provider, (prev, next) {});
      await settle();

      expect(sub.read().value, hasLength(exercisePageSize));
      expect(container.read(provider.notifier).hasMore, isTrue);

      container.read(provider.notifier).loadMore();
      await settle();
      expect(sub.read().value, hasLength(exercisePageSize * 2));
      expect(container.read(provider.notifier).hasMore, isTrue);

      container.read(provider.notifier).loadMore();
      await settle();
      expect(sub.read().value, hasLength(exercisePageSize * 2 + 10));
      expect(container.read(provider.notifier).hasMore, isFalse);
    });

    test('a page of exactly the page size is not "more"', () async {
      await addExercises(exercisePageSize);
      final provider = exercisePagedControllerProvider(null);
      final sub = container.listen(provider, (prev, next) {});
      await settle();

      expect(sub.read().value, hasLength(exercisePageSize));
      expect(container.read(provider.notifier).hasMore, isFalse);
    });

    test('asking twice before the larger window arrives grows it once', () async {
      await addExercises(exercisePageSize * 3);
      final provider = exercisePagedControllerProvider(null);
      final sub = container.listen(provider, (prev, next) {});
      await settle();

      container.read(provider.notifier)
        ..loadMore()
        ..loadMore();
      await settle();

      expect(sub.read().value, hasLength(exercisePageSize * 2));
    });

    test('loadMore at the end changes nothing', () async {
      await addExercises(3);
      final provider = exercisePagedControllerProvider(null);
      final sub = container.listen(provider, (prev, next) {});
      await settle();

      container.read(provider.notifier).loadMore();
      await settle();

      expect(sub.read().value, hasLength(3));
    });

    test('each muscle group has its own window', () async {
      await addExercises(exercisePageSize + 5);
      await exercises.create('Row', category: 'BACK');
      final chest = container.listen(exercisePagedControllerProvider('CHEST'), (prev, next) {});
      final back = container.listen(exercisePagedControllerProvider('BACK'), (prev, next) {});
      await settle();

      expect(chest.read().value, hasLength(exercisePageSize));
      expect(back.read().value!.map((e) => e.name), ['Row']);
      expect(container.read(exercisePagedControllerProvider('BACK').notifier).hasMore, isFalse);
    });

    test('a change in the database reaches the window', () async {
      await addExercises(2);
      final provider = exercisePagedControllerProvider(null);
      final sub = container.listen(provider, (prev, next) {});
      await settle();

      await exercises.create('Added later', category: 'CHEST');
      await settle();

      expect(sub.read().value!.map((e) => e.name), contains('Added later'));
    });
  });

  group('WorkoutSessionsPagedController', () {
    test('a short history is shown whole and there is nothing more to load', () async {
      await addSessions(4);
      final sub = container.listen(workoutSessionsPagedProvider, (prev, next) {});
      await settle();

      expect(sub.read().value, hasLength(4));
      expect(container.read(workoutSessionsPagedProvider.notifier).hasMore, isFalse);
    });

    test('a long history shows the newest page, says there is more, and loadMore reaches back a page', () async {
      await addSessions(sessionsPageSize + 7);
      final sub = container.listen(workoutSessionsPagedProvider, (prev, next) {});
      await settle();

      final first = sub.read().value!;
      expect(first, hasLength(sessionsPageSize));
      expect(container.read(workoutSessionsPagedProvider.notifier).hasMore, isTrue);
      // The extra row that proves "more" must not leak into the window: the oldest session shown is the 40th newest.
      expect(first.last.startedAt!.toUtc(), DateTime.utc(2026, 1, 1).add(const Duration(days: 7)));

      container.read(workoutSessionsPagedProvider.notifier).loadMore();
      await settle();

      expect(sub.read().value, hasLength(sessionsPageSize + 7));
      expect(container.read(workoutSessionsPagedProvider.notifier).hasMore, isFalse);
    });

    test('a page of exactly the page size is not "more"', () async {
      await addSessions(sessionsPageSize);
      final sub = container.listen(workoutSessionsPagedProvider, (prev, next) {});
      await settle();

      expect(sub.read().value, hasLength(sessionsPageSize));
      expect(container.read(workoutSessionsPagedProvider.notifier).hasMore, isFalse);
    });

    test('asking twice before the larger window arrives grows it once', () async {
      await addSessions(sessionsPageSize * 3);
      final sub = container.listen(workoutSessionsPagedProvider, (prev, next) {});
      await settle();

      container.read(workoutSessionsPagedProvider.notifier)
        ..loadMore()
        ..loadMore();
      await settle();

      expect(sub.read().value, hasLength(sessionsPageSize * 2));
    });
  });
}

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}
