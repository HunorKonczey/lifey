import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/domain/food.dart';
import 'package:lifey/features/nutrition/domain/food_usage.dart';

Food _food(String id) =>
    Food(clientId: id, name: id, caloriesPer100g: 100, proteinPer100g: 10);

FoodUsage _usage({required int daysAgo, int count = 1, double grams = 100}) => FoodUsage(
      lastUsedAt: DateTime(2026, 7, 10).subtract(Duration(days: daysAgo)),
      useCount: count,
      lastGrams: grams,
    );

void main() {
  group('recentFoodsByUsage', () {
    test('returns used foods newest first, capped at $recentFoodsCount', () {
      final foods = [for (var i = 0; i < 10; i++) _food('f$i')];
      final usage = {for (var i = 0; i < 8; i++) 'f$i': _usage(daysAgo: i)};

      final recents = recentFoodsByUsage(foods, usage);

      expect(recents.map((f) => f.clientId), ['f0', 'f1', 'f2', 'f3', 'f4', 'f5']);
    });

    test('is empty when nothing was ever logged', () {
      expect(recentFoodsByUsage([_food('a')], const {}), isEmpty);
    });
  });

  group('rankFoodsByUsage', () {
    test('keeps the incoming order when there is no usage', () {
      final foods = [_food('a'), _food('b')];
      expect(rankFoodsByUsage(foods, const {}), same(foods));
    });

    test('orders recents, then frequents by count, then the rest', () {
      // Alphabetical input a..h; recency runs the other way (f newest), so a
      // correct ranking must diverge from the incoming order. 7 used foods —
      // the 7th-most-recent ('g') falls out of the recents cap and competes
      // as a frequent.
      final foods = [for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) _food(id)];
      final usage = {
        'f': _usage(daysAgo: 1),
        'e': _usage(daysAgo: 2),
        'd': _usage(daysAgo: 3),
        'c': _usage(daysAgo: 4),
        'b': _usage(daysAgo: 5),
        'a': _usage(daysAgo: 6),
        'g': _usage(daysAgo: 7, count: 5),
      };

      final ranked = rankFoodsByUsage(foods, usage);

      expect(ranked.map((f) => f.clientId), ['f', 'e', 'd', 'c', 'b', 'a', 'g', 'h']);
    });

    test('demotes once-used foods beyond the recents cap to the alphabetical rest', () {
      // 'z' was used once, long ago — beyond the recents cap and not frequent
      // (useCount < 2), so it must sort in the alphabetical tail *after* the
      // never-used 'a', not ahead of it as a frequent would.
      final foods = [for (final id in ['a', 'c', 'd', 'e', 'f', 'g', 'h', 'z']) _food(id)];
      final usage = {
        for (var i = 0; i < 6; i++) 'cdefgh'[i]: _usage(daysAgo: i + 1),
        'z': _usage(daysAgo: 30, count: 1),
      };

      final ranked = rankFoodsByUsage(foods, usage);

      expect(ranked.map((f) => f.clientId), ['c', 'd', 'e', 'f', 'g', 'h', 'a', 'z']);
    });

    test('breaks frequency ties by recency', () {
      final foods = [for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'x', 'y']) _food(id)];
      final usage = {
        for (var i = 0; i < 6; i++) 'abcdef'[i]: _usage(daysAgo: i + 1),
        'x': _usage(daysAgo: 20, count: 3),
        'y': _usage(daysAgo: 10, count: 3),
      };

      final ranked = rankFoodsByUsage(foods, usage);

      expect(ranked.map((f) => f.clientId).skip(6).take(2), ['y', 'x']);
    });
  });
}
