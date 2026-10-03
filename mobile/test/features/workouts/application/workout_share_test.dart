import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/chat/domain/chat_card.dart';
import 'package:lifey/features/workouts/application/workout_share.dart';
import 'package:lifey/features/workouts/domain/personal_record.dart';
import 'package:lifey/features/workouts/presentation/widgets/workout_success_sheet.dart';

void main() {
  group('pollSessionServerId', () {
    const pause = Duration(milliseconds: 1);

    test('an id that is already there is returned without nudging the outbox', () async {
      var flushes = 0;

      final id = await pollSessionServerId(
        lookup: () async => 481,
        flush: () async => flushes++,
        pause: pause,
      );

      expect(id, 481);
      expect(flushes, 0);
    });

    test('flushes between looks and returns the id as soon as it appears', () async {
      var looks = 0;
      var flushes = 0;

      final id = await pollSessionServerId(
        lookup: () async => ++looks >= 3 ? 481 : null,
        flush: () async => flushes++,
        pause: pause,
      );

      expect(id, 481);
      expect(flushes, 2);
    });

    test('gives up with null after the attempts, and looks one last time', () async {
      var looks = 0;

      final id = await pollSessionServerId(
        lookup: () async {
          looks++;
          return null;
        },
        flush: () async {},
        attempts: 3,
        pause: pause,
      );

      expect(id, isNull);
      expect(looks, 4); // one per attempt, plus the final look
    });

    test('a flush that throws (offline) is not the end of the wait', () async {
      var looks = 0;

      final id = await pollSessionServerId(
        lookup: () async => ++looks >= 2 ? 7 : null,
        flush: () async => throw Exception('offline'),
        pause: pause,
      );

      expect(id, 7);
    });
  });

  group('workoutShareCard', () {
    const progress = WorkoutProgressResult(
      score: 3,
      improvements: [],
      records: [
        WorkoutPrRow(
          exerciseName: 'Bench press',
          chips: ['105 kg'],
          entries: [
            WorkoutRecordEntry(type: PrType.maxWeight, weight: 105, reps: 3, value: 105, delta: 5),
          ],
        ),
      ],
    );

    test('carries the summary, the record count and the start time', () {
      final card = workoutShareCard(
        summary: WorkoutSummary(
          title: '  Push day ',
          duration: const Duration(minutes: 58, seconds: 30),
          volume: 8450.04,
          startedAt: DateTime.utc(2026, 10, 3, 7),
          exerciseCount: 6,
          sessionClientId: 'abc',
        ),
        result: progress,
      );

      expect(card.workoutKind, ChatWorkoutKind.strength);
      expect(card.title, 'Push day');
      expect(card.durationSeconds, 3510);
      expect(card.volumeKg, 8450.0);
      expect(card.exerciseCount, 6);
      expect(card.recordCount, 1);
      expect(card.occurredAt, DateTime.utc(2026, 10, 3, 7));
      // Resolved at send time, never here.
      expect(card.sessionId, isNull);
    });

    test('zeros and blanks become nothing, so the card never prints "0 exercises"', () {
      final card = workoutShareCard(
        summary: const WorkoutSummary(title: '   '),
        result: const WorkoutProgressResult(score: 0, improvements: [], records: []),
        now: DateTime.utc(2026, 10, 3, 9),
      );

      expect(card.title, isNull);
      expect(card.durationSeconds, isNull);
      expect(card.volumeKg, isNull);
      expect(card.exerciseCount, isNull);
      expect(card.recordCount, isNull);
      expect(card.occurredAt, DateTime.utc(2026, 10, 3, 9));
    });
  });

  group('recordShareCard', () {
    final when = DateTime.utc(2026, 10, 3, 7);

    test('rebuilds the old record from the delta the sheet already shows', () {
      final card = recordShareCard(
        exerciseName: 'Bench press',
        entry: const WorkoutRecordEntry(type: PrType.maxWeight, weight: 102.5, reps: 3, value: 102.5, delta: 2.5),
        occurredAt: when,
      );

      expect(card.exerciseName, 'Bench press');
      expect(card.prKind, ChatPrKind.maxWeight);
      expect(card.value, 102.5);
      expect(card.previousValue, 100);
      expect(card.delta, 2.5);
      expect(card.weightKg, 102.5);
      expect(card.reps, 3);
    });

    test('a first record claims no previous value', () {
      final card = recordShareCard(
        exerciseName: 'Squat',
        entry: const WorkoutRecordEntry(type: PrType.estimatedOneRm, weight: 100, reps: 5, value: 116.67),
        occurredAt: when,
      );

      expect(card.prKind, ChatPrKind.estimatedOneRm);
      expect(card.previousValue, isNull);
    });

    test('every record type has a wire name the server knows', () {
      for (final type in PrType.values) {
        final card = recordShareCard(
          exerciseName: 'x',
          entry: WorkoutRecordEntry(type: type, weight: 50, reps: 5, value: 50),
          occurredAt: when,
        );
        expect(ChatPrKind.fromWire(card.prKind.wire), card.prKind);
      }
    });

    test('a reps record keeps reps as its value and the weight as context', () {
      final card = recordShareCard(
        exerciseName: 'Squat',
        entry: const WorkoutRecordEntry(type: PrType.repsAtWeight, weight: 80, reps: 8, value: 8, delta: 2),
        occurredAt: when,
      );

      expect(card.prKind, ChatPrKind.repsAtWeight);
      expect(card.value, 8);
      expect(card.previousValue, 6);
      expect(card.weightKg, 80);
    });
  });
}
