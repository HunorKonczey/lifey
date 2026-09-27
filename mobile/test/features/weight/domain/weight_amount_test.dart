import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/weight/domain/weight_amount.dart';

void main() {
  group('stepping', () {
    test('a thousand +0.1 steps end exactly 100 kg up — no float drift', () {
      var amount = WeightAmount.fromKg(64.5);
      for (var i = 0; i < 1000; i++) {
        amount = amount.step(1);
      }

      expect(amount.grams, 164500);
      expect(amount.kg, 164.5);
    });

    test('64.5 → 64.6 → 64.7 is exactly what a person would type', () {
      final up = WeightAmount.fromKg(64.5).step(1).step(1);

      expect(up.kg, 64.7); // not 64.699999999999996
      expect(up, WeightAmount.tryParse('64.7'));
    });

    test('up then down comes back to the same value', () {
      final start = WeightAmount.fromKg(72.3);
      var amount = start;
      for (var i = 0; i < 57; i++) {
        amount = amount.step(1);
      }
      for (var i = 0; i < 57; i++) {
        amount = amount.step(-1);
      }

      expect(amount, start);
    });

    test('stops at 1 kg and at 500 kg', () {
      expect(WeightAmount.fromKg(1.0).step(-1).grams, 1000);
      expect(WeightAmount.fromKg(1.0).canStepDown, isFalse);
      expect(WeightAmount.fromKg(500.0).step(1).grams, 500000);
      expect(WeightAmount.fromKg(500.0).canStepUp, isFalse);
      expect(WeightAmount.fromKg(64.5).canStepDown, isTrue);
      expect(WeightAmount.fromKg(64.5).canStepUp, isTrue);
    });

    test('a weight with more precision than a step keeps it (64.55 → 64.65)', () {
      expect(WeightAmount.fromKg(64.55).step(1).grams, 64650);
    });
  });

  group('parsing what was typed', () {
    test('dot, comma and whole numbers', () {
      expect(WeightAmount.tryParse('64.5')!.grams, 64500);
      expect(WeightAmount.tryParse('64,5')!.grams, 64500);
      expect(WeightAmount.tryParse(' 64 ')!.grams, 64000);
    });

    test('rounds to the gram', () {
      expect(WeightAmount.tryParse('64.5004')!.grams, 64500);
      expect(WeightAmount.tryParse('64.5006')!.grams, 64501);
    });

    test('rejects what is not a weight', () {
      for (final bad in ['', 'abc', '0', '-3', '0.5', '501', 'NaN', 'Infinity']) {
        expect(WeightAmount.tryParse(bad), isNull, reason: bad);
      }
    });
  });

  test('fromKg clamps into the accepted range', () {
    expect(WeightAmount.fromKg(0.2).grams, WeightAmount.minGrams);
    expect(WeightAmount.fromKg(900).grams, WeightAmount.maxGrams);
  });
}
