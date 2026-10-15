import 'dart:math';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/core/sync/sync_engine.dart';
import 'package:lifey/features/workouts/application/session_pr_counts.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';

/// The record counts the database computes (LIF-158) against the Dart algorithm they replace - `computeSessionPrCounts`, which
/// stays as the reference. Hand-written cases for each rule, then randomised histories that must come out identical.
void main() {
  late AppDatabase db;
  late WorkoutSessionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorkoutSessionRepository(db, OutboxWriter(db, _NoopSyncEngine(db, Dio())));
  });

  tearDown(() => db.close());

  Future<String> logged(
    DateTime at,
    List<(String exercise, double weight, int reps)> sets, {
    bool finished = true,
    String kind = 'STRENGTH',
  }) =>
      repo.create(
        startedAt: at,
        finishedAt: finished ? at.add(const Duration(hours: 1)) : null,
        exercises: const [],
        sets: [
          for (var i = 0; i < sets.length; i++)
            ExerciseSetInput(exerciseClientId: sets[i].$1, reps: sets[i].$3, weight: sets[i].$2, performedAt: at.add(Duration(minutes: i))),
        ],
        sessionKind: kind,
        activityType: kind == 'CARDIO' ? 'RUNNING' : null,
        movingSeconds: kind == 'CARDIO' ? 600 : null,
      );

  Future<Map<String, int>> sql() => repo.watchStrengthPrCounts().first;

  /// What the Dart algorithm says about the strength sessions of the same database.
  Future<Map<String, int>> reference() async {
    final all = await repo.watchAll().first;
    final counts = computeSessionPrCounts(all);
    final strength = {for (final s in all) if (!s.isCardio) s.clientId};
    return {for (final e in counts.entries) if (strength.contains(e.key)) e.key: e.value};
  }

  DateTime day(int d) => DateTime.utc(2026, 1, 1).add(Duration(days: d, hours: 17));

  group('the rules, one by one', () {
    test('the first time an exercise is done sets no record - there is nothing to beat', () async {
      await logged(day(1), [('bench', 60, 5), ('bench', 62.5, 5)]);

      // The second set beats the first within the same session: a heavier weight and a better 1RM.
      expect(await sql(), isNotEmpty);
      final first = await logged(day(0), [('squat', 100, 5)]);
      expect((await sql()).containsKey(first), isFalse);
    });

    test('a heavier weight than any earlier set is a record, and so is the better estimated 1RM', () async {
      await logged(day(1), [('bench', 60, 5)]);
      final second = await logged(day(2), [('bench', 62.5, 5)]);

      // maxWeight + estimatedOneRm; no reps record, as nothing was done at 62.5 kg before.
      expect((await sql())[second], 2);
    });

    test('equalling the best is not a record - strictly greater', () async {
      await logged(day(1), [('bench', 60, 5)]);
      final again = await logged(day(2), [('bench', 60, 5)]);

      expect((await sql()).containsKey(again), isFalse);
    });

    test('more reps at the same weight is a record; a weight never done before is not', () async {
      await logged(day(1), [('bench', 60, 5)]);
      final moreReps = await logged(day(2), [('bench', 60, 6)]);
      final newWeight = await logged(day(3), [('bench', 55, 5)]);

      final counts = await sql();
      // 60 x 6: a better 1RM and more reps at 60 (the max weight is only equalled).
      expect(counts[moreReps], 2);
      expect(counts.containsKey(newWeight), isFalse);
    });

    test('bodyweight (0 kg) has a reps record but no weight or 1RM record', () async {
      await logged(day(1), [('pullup', 0, 8)]);
      final better = await logged(day(2), [('pullup', 0, 10)]);

      expect((await sql())[better], 1);
    });

    test('three sets in a row that each beat the last are still one record of that kind', () async {
      await logged(day(1), [('bench', 60, 5)]);
      final climbing = await logged(day(2), [('bench', 62.5, 5), ('bench', 65, 5), ('bench', 67.5, 5)]);

      expect((await sql())[climbing], 2);
    });

    test('the records of two exercises in one session add up', () async {
      await logged(day(1), [('bench', 60, 5), ('squat', 80, 5)]);
      final both = await logged(day(2), [('bench', 62.5, 5), ('squat', 85, 5)]);

      expect((await sql())[both], 4);
    });

    test('a session is judged against what came before it in time, whatever order they were logged in', () async {
      final later = await logged(day(5), [('bench', 70, 5)]);
      final earlier = await logged(day(1), [('bench', 60, 5)]);
      final middle = await logged(day(3), [('bench', 65, 5)]);

      final counts = await sql();
      expect(counts.containsKey(earlier), isFalse);
      expect(counts[middle], 2);
      expect(counts[later], 2);
    });

    test('sessions are replayed in the order they started, not in the order their sets were performed', () async {
      // Session A started first but one of its sets was logged long after session B had begun and ended.
      final a = await repo.create(
        startedAt: day(1),
        finishedAt: day(1).add(const Duration(hours: 1)),
        exercises: const [],
        sets: [ExerciseSetInput(exerciseClientId: 'bench', reps: 5, weight: 100, performedAt: day(10))],
      );
      final b = await repo.create(
        startedAt: day(5),
        finishedAt: day(5).add(const Duration(hours: 1)),
        exercises: const [],
        sets: [ExerciseSetInput(exerciseClientId: 'bench', reps: 5, weight: 80, performedAt: day(6))],
      );

      // A comes first and sets nothing; B is judged against A's 100 kg and beats nothing. (Ordered by when the sets were performed,
      // B would come first and A would "beat" it.)
      final counts = await sql();
      expect(counts.containsKey(a), isFalse);
      expect(counts.containsKey(b), isFalse);
      expect(counts, await reference());
    });

    test('an unfinished session counts for nothing, and is not a baseline either', () async {
      await logged(day(1), [('bench', 100, 5)], finished: false);
      final real = await logged(day(2), [('bench', 60, 5)]);
      final heavier = await logged(day(3), [('bench', 62.5, 5)]);

      final counts = await sql();
      expect(counts.containsKey(real), isFalse);
      expect(counts[heavier], 2);
    });

    test('a cardio session is not part of the strength counts', () async {
      await logged(day(1), [('bench', 60, 5)]);
      await logged(day(2), [], kind: 'CARDIO');
      final heavier = await logged(day(3), [('bench', 62.5, 5)]);

      expect((await sql()).keys, [heavier]);
    });

    test('a session with a delete queued is left out, and is not a baseline', () async {
      final big = await logged(day(1), [('bench', 100, 5)]);
      final real = await logged(day(2), [('bench', 60, 5)]);
      await repo.delete(big);

      final counts = await sql();
      expect(counts.containsKey(big), isFalse);
      expect(counts.containsKey(real), isFalse);
    });

    test('an empty database counts nothing', () async {
      expect(await sql(), isEmpty);
    });
  });

  group('the same answer as the Dart algorithm', () {
    const weights = [0.0, 20.0, 40.0, 60.0, 60.0, 62.5, 80.0, 82.5, 100.0];

    for (var seed = 1; seed <= 30; seed++) {
      test('a random history, seed $seed', () async {
        final random = Random(seed);
        final exercises = ['bench', 'squat', 'row', 'pullup'];
        final sessionCount = 6 + random.nextInt(25);
        // Days are drawn without repeats: two sessions in the same second would leave their order to a tie-break, which the
        // two implementations are free to settle differently.
        final days = (List.generate(120, (i) => i)..shuffle(random)).take(sessionCount).toList();

        for (final d in days) {
          final setCount = 1 + random.nextInt(9);
          final sets = [
            for (var i = 0; i < setCount; i++)
              (exercises[random.nextInt(exercises.length)], weights[random.nextInt(weights.length)], 1 + random.nextInt(12)),
          ];
          final roll = random.nextInt(10);
          await logged(day(d), sets, finished: roll != 0, kind: roll == 1 ? 'CARDIO' : 'STRENGTH');
        }

        expect(await sql(), await reference());
      });
    }
  });

  test('it follows the data: logging a record changes the counts', () async {
    await logged(day(1), [('bench', 60, 5)]);
    final emitted = <Map<String, int>>[];
    final sub = repo.watchStrengthPrCounts().listen(emitted.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();
    expect(emitted.last, isEmpty);

    final heavier = await logged(day(2), [('bench', 62.5, 5)]);
    await pumpEventQueue();

    expect(emitted.last[heavier], 2);
  });
}

class _NoopSyncEngine extends SyncEngine {
  _NoopSyncEngine(super.db, super.dio);

  @override
  Future<void> sync() async {}
}
