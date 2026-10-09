import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/domain/food.dart';

/// `FoodServing` (LIF-146): what the server sends and the column holds survives a round trip; a bad entry never takes the food down.
void main() {
  test('encode / decode round-trips in order, and none is null', () {
    const servings = [FoodServing(name: '1 glass', grams: 200), FoodServing(name: '1 spoon', grams: 15.5)];

    expect(FoodServing.decode(FoodServing.encode(servings)), servings);
    expect(FoodServing.encode(const []), isNull);
    expect(FoodServing.decode(null), isEmpty);
    expect(FoodServing.decode(''), isEmpty);
  });

  test('listFromJson drops anything malformed and keeps the rest', () {
    final list = FoodServing.listFromJson([
      {'name': '1 glass', 'grams': 200},
      {'name': '', 'grams': 100},
      {'name': 'no grams'},
      {'name': 'zero', 'grams': 0},
      {'name': 'negative', 'grams': -5},
      {'name': 7, 'grams': 5},
      'not a map',
      {'name': '1 cup', 'grams': 250.5},
    ]);

    expect(list, const [FoodServing(name: '1 glass', grams: 200), FoodServing(name: '1 cup', grams: 250.5)]);
    expect(FoodServing.listFromJson(null), isEmpty);
    expect(FoodServing.listFromJson('x'), isEmpty);
  });

  test('a corrupt column reads as no servings', () {
    expect(FoodServing.decode('not json'), isEmpty);
    expect(FoodServing.decode('{"a":1}'), isEmpty);
  });
}
