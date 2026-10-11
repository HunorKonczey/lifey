import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/chat/domain/chat_card.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';

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

    test('a meal card round-trips, keeps an unknown fibre unknown and has nothing to open (LIF-123)', () {
      final card = MealChatCard(
        occurredAt: when,
        mealType: MealType.lunch,
        calories: 620,
        proteinGrams: 42,
        carbsGrams: 66,
        fatGrams: 18,
        fiberGrams: 7.5,
        fiberSugarPartial: true,
        itemCount: 5,
        itemNames: const ['Chicken', 'Rice', 'Broccoli'],
      );

      final json = card.toJson();
      final parsed = ChatCard.tryParse(json) as MealChatCard;

      expect(json['kind'], 'MEAL');
      expect(json, isNot(contains('sessionId')));
      expect((json['meal'] as Map), isNot(contains('sugarGrams')), reason: 'unknown is not sent as 0');
      expect(parsed.mealType, MealType.lunch);
      expect(parsed.calories, 620);
      expect(parsed.fiberGrams, 7.5);
      expect(parsed.sugarGrams, isNull);
      expect(parsed.fiberSugarPartial, isTrue);
      expect(parsed.itemNames, ['Chicken', 'Rice', 'Broccoli']);
      expect(parsed.moreItems, 2);
      expect(parsed.sessionId, isNull);
      expect(parsed.withSessionId(481).sessionId, isNull, reason: 'a meal has no session to point at');
    });

    test('a meal card built from a logged meal sums it, the way the meal row does', () {
      final meal = Meal(
        clientId: 'm',
        dateTime: DateTime(2026, 10, 3, 12, 30),
        mealType: MealType.dinner,
        entries: const [
          MealEntry(foodClientId: 'a', foodName: 'Salmon', quantityInGrams: 150, calories: 300, protein: 30, carbs: 0, fat: 20, fiber: 0, sugar: 0),
          MealEntry(foodClientId: 'b', foodName: 'Rice', quantityInGrams: 200, calories: 260, protein: 5, carbs: 56, fat: 1, fiber: 1, sugar: 0.4),
          // No figure: not known, so the card says only some foods have one.
          MealEntry(foodClientId: 'c', foodName: 'Sauce', quantityInGrams: 30, calories: 60, protein: 1, carbs: 5, fat: 4),
          MealEntry(foodClientId: 'd', foodName: 'Salad', quantityInGrams: 80, calories: 20, protein: 1, carbs: 3, fat: 0, fiber: 2, sugar: 1),
        ],
      );

      final card = MealChatCard.fromMeal(meal);

      expect(card.mealType, MealType.dinner);
      expect(card.calories, 640);
      expect(card.proteinGrams, 37);
      expect(card.carbsGrams, 64);
      expect(card.fatGrams, 25);
      expect(card.fiberGrams, 3);
      expect(card.sugarGrams, closeTo(1.4, 1e-9));
      expect(card.fiberSugarPartial, isTrue);
      expect(card.itemCount, 4);
      expect(card.itemNames, ['Salmon', 'Rice', 'Sauce']);
      expect(card.moreItems, 1);
    });

    test('a meal card with no fibre figure at all stays empty, not zero', () {
      final card = MealChatCard.fromMeal(Meal(
        clientId: 'm',
        dateTime: DateTime(2026, 10, 3),
        mealType: MealType.snack,
        entries: const [MealEntry(foodClientId: 'a', foodName: 'Apple', quantityInGrams: 100, calories: 52, protein: 0, carbs: 14, fat: 0)],
      ));

      expect(card.fiberGrams, isNull);
      expect(card.sugarGrams, isNull);
      expect(card.fiberSugar.isEmpty, isTrue);
    });

    test('a malformed meal card becomes an unknown one instead of throwing', () {
      expect(
        ChatCard.tryParse({'kind': 'MEAL', 'occurredAt': when.toIso8601String(), 'meal': {'mealType': 'BRUNCH', 'calories': 1}}),
        isA<UnknownChatCard>(),
      );
      expect(ChatCard.tryParse({'kind': 'MEAL', 'occurredAt': when.toIso8601String()}), isA<UnknownChatCard>());
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
