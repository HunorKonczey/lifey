import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/nutrition/domain/meal_days.dart';

void main() {
  group('lastSevenDays', () {
    test('six days back and today, oldest first, at local midnight', () {
      final days = lastSevenDays(DateTime(2026, 9, 24, 15, 40));
      expect(days.first, DateTime(2026, 9, 18));
      expect(days.last, DateTime(2026, 9, 24));
      expect(days.length, 7);
      expect(days.map((d) => d.day), [18, 19, 20, 21, 22, 23, 24]);
    });

    test('crosses a month and a year boundary', () {
      expect(lastSevenDays(DateTime(2026, 1, 3)).map((d) => d.toIso8601String().substring(0, 10)), [
        '2025-12-28',
        '2025-12-29',
        '2025-12-30',
        '2025-12-31',
        '2026-01-01',
        '2026-01-02',
        '2026-01-03',
      ]);
    });

    test('is calendar arithmetic — one date per day across the DST change', () {
      // Whatever the machine's zone, 7 consecutive distinct dates.
      final days = lastSevenDays(DateTime(2026, 3, 30, 12));
      expect(days.map((d) => d.day).toSet().length, 7);
      for (final d in days) {
        expect(d.hour, 0);
      }
    });
  });

  group('effectiveMealDay', () {
    final now = DateTime(2026, 9, 24, 8);

    test('no pick means today', () {
      expect(effectiveMealDay(null, now), DateTime(2026, 9, 24));
    });

    test('a pick inside the strip is kept (time of day dropped)', () {
      expect(effectiveMealDay(DateTime(2026, 9, 21, 13, 5), now), DateTime(2026, 9, 21));
      expect(effectiveMealDay(DateTime(2026, 9, 18), now), DateTime(2026, 9, 18));
    });

    test('a pick that has scrolled out of the strip (app open past midnight) falls back to today', () {
      expect(effectiveMealDay(DateTime(2026, 9, 17), now), DateTime(2026, 9, 24));
    });

    test('a pick in the future falls back to today', () {
      expect(effectiveMealDay(DateTime(2026, 9, 25), now), DateTime(2026, 9, 24));
    });
  });
}
