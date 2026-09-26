import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/domain/hr_zones.dart';

void main() {
  group('heartRateZone', () {
    test('the canvas reading: 152 bpm at a 190 maximum is Zone 3', () {
      expect(heartRateZone(152, 190), 3);
    });

    test('the upper edge of a band belongs to that band', () {
      expect(heartRateZone(114, 190), 1); // 60 %
      expect(heartRateZone(133, 190), 2); // 70 %
      expect(heartRateZone(152, 190), 3); // 80 %
      expect(heartRateZone(171, 190), 4); // 90 %
      expect(heartRateZone(172, 190), 5);
    });

    test('very low and above-maximum readings stay in 1 and 5', () {
      expect(heartRateZone(48, 190), 1);
      expect(heartRateZone(205, 190), 5);
    });
  });

  group('maxHeartRateForAge', () {
    test('220 minus the age', () {
      expect(maxHeartRateForAge(30), 190);
      expect(maxHeartRateForAge(55), 165);
    });

    test('an age no adult has gives no maximum', () {
      expect(maxHeartRateForAge(3), isNull);
      expect(maxHeartRateForAge(140), isNull);
    });
  });

  group('ageOn', () {
    test('counts whole years, not yet a year older before the birthday', () {
      final birth = DateTime(1996, 9, 26);
      expect(ageOn(birth, DateTime(2026, 9, 25)), 29);
      expect(ageOn(birth, DateTime(2026, 9, 26)), 30);
      expect(ageOn(birth, DateTime(2027, 1, 1)), 30);
    });
  });
}
