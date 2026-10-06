import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/domain/food.dart';
import 'package:lifey/features/nutrition/domain/off_food_plan.dart';
import 'package:lifey/features/nutrition/domain/off_search.dart';

const _item = OffSearchItem(
  barcode: '4056489827702',
  name: 'Csirkemell',
  brand: 'Pikok',
  caloriesPer100g: 110,
  proteinPer100g: 14,
  carbsPer100g: 2.4,
  fatPer100g: 4.9,
);

Food _food(String id, String name, {String? barcode, bool hidden = false}) =>
    Food(clientId: id, name: name, caloriesPer100g: 100, proteinPer100g: 10, barcode: barcode, hidden: hidden);

void main() {
  test('nothing in the way: create it under the product name', () {
    final plan = planOffFood(_item, [_food('a', 'Rice')]);

    expect(plan, isA<CreateOffFood>());
    expect((plan as CreateOffFood).name, 'Csirkemell');
  });

  test('no foods at all: create it', () {
    expect(planOffFood(_item, const []), isA<CreateOffFood>());
  });

  test('the user already has a food with this barcode: use it, whatever it is called', () {
    final mine = _food('mine', 'My chicken', barcode: '4056489827702');

    final plan = planOffFood(_item, [_food('a', 'Rice'), mine]);

    expect(plan, isA<UseExistingFood>());
    expect((plan as UseExistingFood).food, same(mine));
  });

  test('the barcode wins over a name clash', () {
    final byBarcode = _food('b', 'Something else', barcode: '4056489827702');
    final byName = _food('n', 'Csirkemell');

    final plan = planOffFood(_item, [byName, byBarcode]);

    expect((plan as UseExistingFood).food, same(byBarcode));
  });

  test('the name is taken by a different food: create it as "Name (Brand)"', () {
    final plan = planOffFood(_item, [_food('n', 'Csirkemell')]);

    expect((plan as CreateOffFood).name, 'Csirkemell (Pikok)');
  });

  test('the name clash ignores case and surrounding spaces, like the backend', () {
    final plan = planOffFood(_item, [_food('n', '  CSIRKEMELL ')]);

    expect((plan as CreateOffFood).name, 'Csirkemell (Pikok)');
  });

  test('without a brand the suffix is OpenFoodFacts', () {
    const noBrand = OffSearchItem(barcode: '1', name: 'Túró Rudi', caloriesPer100g: 400, proteinPer100g: 11);

    final plan = planOffFood(noBrand, [_food('n', 'Túró Rudi')]);

    expect((plan as CreateOffFood).name, 'Túró Rudi (OpenFoodFacts)');
  });

  test('even the suffixed name is taken: it is the same product saved before — use that food', () {
    final before = _food('before', 'Csirkemell (Pikok)');

    final plan = planOffFood(_item, [_food('n', 'Csirkemell'), before]);

    expect((plan as UseExistingFood).food, same(before));
  });

  test('hidden foods (one-off macro entries) never block a name and are never reused', () {
    final plan = planOffFood(_item, [_food('h', 'Csirkemell', hidden: true), _food('hb', 'X', barcode: '4056489827702', hidden: true)]);

    expect(plan, isA<CreateOffFood>());
    expect((plan as CreateOffFood).name, 'Csirkemell');
  });

  test('a food without a barcode is never matched by barcode', () {
    final plan = planOffFood(_item, [_food('a', 'Other')]);

    expect(plan, isA<CreateOffFood>());
  });

  test('the product name is trimmed', () {
    const spaced = OffSearchItem(barcode: '2', name: '  Skyr  ', caloriesPer100g: 63, proteinPer100g: 11);

    expect((planOffFood(spaced, const []) as CreateOffFood).name, 'Skyr');
  });
}
