import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/chat/domain/chat_card.dart';

void main() {
  final when = DateTime.utc(2026, 10, 3, 7, 12);

  group('wire format', () {
    test('a workout card round-trips through its own JSON', () {
      final card = WorkoutChatCard(
        occurredAt: when,
        sessionId: 481,
        workoutKind: ChatWorkoutKind.strength,
        title: 'Push day',
        durationSeconds: 3600,
        volumeKg: 8450,
        exerciseCount: 6,
        recordCount: 2,
      );

      final parsed = ChatCard.tryParse(card.toJson()) as WorkoutChatCard;

      expect(parsed.sessionId, 481);
      expect(parsed.title, 'Push day');
      expect(parsed.durationSeconds, 3600);
      expect(parsed.volumeKg, 8450);
      expect(parsed.exerciseCount, 6);
      expect(parsed.recordCount, 2);
      expect(parsed.isCardio, isFalse);
      expect(parsed.occurredAt.toUtc(), when);
    });

    test('a PR card round-trips and knows how far it moved the record', () {
      final card = PrChatCard(
        occurredAt: when,
        exerciseName: 'Bench press',
        prKind: ChatPrKind.maxWeight,
        value: 102.5,
        previousValue: 100,
        weightKg: 102.5,
        reps: 3,
      );

      final parsed = ChatCard.tryParse(card.toJson()) as PrChatCard;

      expect(parsed.exerciseName, 'Bench press');
      expect(parsed.prKind, ChatPrKind.maxWeight);
      expect(parsed.delta, 2.5);
      expect(parsed.sessionId, isNull);
    });

    test('the first record of an exercise has no delta to claim', () {
      final card = PrChatCard(
        occurredAt: when,
        exerciseName: 'Squat',
        prKind: ChatPrKind.estimatedOneRm,
        value: 140,
      );

      expect(card.delta, isNull);
    });

    test('only the matching sub-object goes on the wire, and no nulls', () {
      final workout = WorkoutChatCard(occurredAt: when, workoutKind: ChatWorkoutKind.cardio).toJson();
      final pr = PrChatCard(
        occurredAt: when,
        exerciseName: 'Squat',
        prKind: ChatPrKind.repsAtWeight,
        value: 8,
      ).toJson();

      expect(workout.containsKey('pr'), isFalse);
      expect(workout.containsKey('sessionId'), isFalse);
      expect((workout['workout'] as Map).containsKey('title'), isFalse);
      expect(pr.containsKey('workout'), isFalse);
      expect(pr['occurredAt'], '2026-10-03T07:12:00.000Z');
      expect((pr['pr'] as Map)['prType'], 'REPS_AT_WEIGHT');
    });

    test('the server wire names map to the three record kinds and back', () {
      for (final kind in ChatPrKind.values) {
        expect(ChatPrKind.fromWire(kind.wire), kind);
      }
      expect(ChatPrKind.fromWire('NOPE'), isNull);
      expect(ChatPrKind.fromWire(null), isNull);
    });
  });

  group('tolerance', () {
    test('a kind this build does not know is kept, with its raw JSON', () {
      final raw = {
        'kind': 'MEAL',
        'occurredAt': '2026-10-03T07:12:00Z',
        'meal': {'name': 'Lunch'},
      };

      final parsed = ChatCard.tryParse(raw);

      expect(parsed, isA<UnknownChatCard>());
      expect(parsed!.kindCode, 'MEAL');
      // Round-trips through the local cache untouched.
      expect(parsed.toJson(), raw);
    });

    test('a known kind with a broken body degrades instead of throwing', () {
      expect(
        ChatCard.tryParse({'kind': 'PR', 'occurredAt': '2026-10-03T07:12:00Z', 'pr': {'exerciseName': 'x'}}),
        isA<UnknownChatCard>(),
      );
      expect(
        ChatCard.tryParse({'kind': 'WORKOUT', 'occurredAt': '2026-10-03T07:12:00Z'}),
        isA<UnknownChatCard>(),
      );
    });

    test('no card at all, or nothing readable, is null', () {
      expect(ChatCard.tryParse(null), isNull);
      expect(ChatCard.tryParse('nope'), isNull);
      expect(ChatCard.tryParse({'occurredAt': '2026-10-03T07:12:00Z'}), isNull);
      expect(ChatCard.tryParse({'kind': 'PR'}), isNull);
    });
  });
}
