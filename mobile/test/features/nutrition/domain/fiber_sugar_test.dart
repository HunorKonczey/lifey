import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/domain/fiber_sugar.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';

MealEntry _entry({double? fiber, double? sugar}) => MealEntry(
      foodClientId: 'f',
      foodName: 'Food',
      quantityInGrams: 100,
      calories: 100,
      protein: 5,
      carbs: 10,
      fat: 2,
      fiber: fiber,
      sugar: sugar,
    );

Meal _meal(List<MealEntry> entries) =>
    Meal(clientId: 'm', dateTime: DateTime(2026, 9, 24, 12), mealType: MealType.lunch, entries: entries);

/// LIF-148: fibre and sugars of a meal / a day are the sum of what is known - not known is not 0, and a partial sum says so.
void main() {
  group('FiberSugarTotals.of', () {
    test('adds up the known figures', () {
      final t = FiberSugarTotals.of([(fiber: 5.0, sugar: 1.0), (fiber: 3.6, sugar: 15.0)]);

      expect(t.fiber, closeTo(8.6, 1e-9));
      expect(t.sugar, closeTo(16.0, 1e-9));
      expect(t.partial, isFalse);
      expect(t.isEmpty, isFalse);
    });

    test('is empty (null, not 0) when no entry has a figure', () {
      final t = FiberSugarTotals.of([(fiber: null, sugar: null), (fiber: null, sugar: null)]);

      expect(t.fiber, isNull);
      expect(t.sugar, isNull);
      expect(t.partial, isFalse);
      expect(t.isEmpty, isTrue);
    });

    test('an empty list is empty', () {
      expect(FiberSugarTotals.of(const []).isEmpty, isTrue);
    });

    test('an entry without a figure leaves the sum of the others and makes it partial', () {
      final t = FiberSugarTotals.of([(fiber: 10.0, sugar: 1.0), (fiber: null, sugar: null)]);

      expect(t.fiber, 10);
      expect(t.sugar, 1);
      expect(t.partial, isTrue);
    });

    test('a food known for fibre only keeps the fibre, leaves sugar null, and is partial', () {
      final t = FiberSugarTotals.of([(fiber: 4.0, sugar: null)]);

      expect(t.fiber, 4);
      expect(t.sugar, isNull);
      expect(t.partial, isTrue);
      expect(t.isEmpty, isFalse);
    });

    test('a genuine 0 is a figure, not "unknown"', () {
      final t = FiberSugarTotals.of([(fiber: 0.0, sugar: 0.0)]);

      expect(t.fiber, 0);
      expect(t.sugar, 0);
      expect(t.partial, isFalse);
      expect(t.isEmpty, isFalse);
    });
  });

  group('Meal.fiberSugar and the day extension', () {
    test('a meal sums its entries', () {
      final meal = _meal([_entry(fiber: 2, sugar: 3), _entry(fiber: 1.5, sugar: 0.5)]);

      expect(meal.fiberSugar.fiber, 3.5);
      expect(meal.fiberSugar.sugar, 3.5);
    });

    test('a day sums every entry of every meal', () {
      final meals = [
        _meal([_entry(fiber: 2, sugar: 3)]),
        _meal([_entry(fiber: 4, sugar: 1), _entry()]),
      ];

      final day = meals.fiberSugar;
      expect(day.fiber, 6);
      expect(day.sugar, 4);
      expect(day.partial, isTrue);
    });

    test('a meal with no entries has nothing to show', () {
      expect(_meal(const []).fiberSugar.isEmpty, isTrue);
      expect(<Meal>[].fiberSugar.isEmpty, isTrue);
    });
  });
}
