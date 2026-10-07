import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/utils/date_math.dart';

void main() {
  group('addDays', () {
    test('a local midnight stays an exact midnight, on every day of the year', () {
      // With `Duration(days: 1)` the two daylight-saving nights land at 23:00 or 01:00
      // (in any zone that observes it); calendar arithmetic never does.
      var day = DateTime(2026);
      for (var i = 0; i < 365; i++) {
        final next = addDays(day, 1);
        expect(next, DateTime(day.year, day.month, day.day + 1), reason: '$day + 1');
        expect(next.hour, 0, reason: '$day + 1');
        day = next;
      }
    });

    test('a week step from a Monday lands on the next Monday at midnight, across the whole year', () {
      var monday = DateTime(2026, 1, 5);
      for (var i = 0; i < 52; i++) {
        final next = addDays(monday, 7);
        expect(next.weekday, DateTime.monday, reason: '$monday + 7');
        expect(next.hour, 0, reason: '$monday + 7');
        expect(addDays(next, -7), monday, reason: '$next - 7');
        monday = next;
      }
    });

    test('keeps the wall-clock time of day', () {
      final evening = DateTime(2026, 10, 24, 20, 30);
      expect(addDays(evening, 3), DateTime(2026, 10, 27, 20, 30));
      expect(addDays(evening, -1), DateTime(2026, 10, 23, 20, 30));
    });

    test('zero days is the same instant', () {
      final d = DateTime(2026, 3, 29, 12, 5);
      expect(addDays(d, 0), d);
    });

    test('a UTC value stays UTC', () {
      final utc = DateTime.utc(2026, 10, 24, 22);
      final moved = addDays(utc, 1);
      expect(moved.isUtc, isTrue);
      expect(moved, DateTime.utc(2026, 10, 25, 22));
    });
  });

  group('calendarDaysBetween', () {
    test('adjacent days are one apart, also over the night the clocks go forward', () {
      // `difference().inDays` of those two midnights is 0 where the day has 23 hours.
      expect(calendarDaysBetween(DateTime(2026, 3, 29), DateTime(2026, 3, 30)), 1);
      expect(calendarDaysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 29)), 1);
    });

    test('and over the night they go back', () {
      expect(calendarDaysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 25)), 1);
      expect(calendarDaysBetween(DateTime(2026, 10, 25), DateTime(2026, 10, 26)), 1);
    });

    test('a span that crosses a change counts its calendar days', () {
      expect(calendarDaysBetween(DateTime(2026, 3, 24), DateTime(2026, 3, 30)), 6);
      expect(calendarDaysBetween(DateTime(2026, 3, 10), DateTime(2026, 4, 9)), 30);
      expect(calendarDaysBetween(DateTime(2026, 10, 20), DateTime(2026, 10, 26)), 6);
    });

    test('ignores the time of day and is negative backwards', () {
      expect(calendarDaysBetween(DateTime(2026, 10, 5, 23, 59), DateTime(2026, 10, 6, 0, 1)), 1);
      expect(calendarDaysBetween(DateTime(2026, 10, 6), DateTime(2026, 10, 1)), -5);
      expect(calendarDaysBetween(DateTime(2026, 10, 6, 8), DateTime(2026, 10, 6, 20)), 0);
    });
  });
}
