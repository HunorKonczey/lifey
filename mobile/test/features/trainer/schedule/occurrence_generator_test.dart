import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/trainer/schedule/domain/occurrence_generator.dart';
import 'package:lifey/features/trainer/schedule/domain/schedule.dart';

/// Port of the backend's `OccurrenceGenerator` behaviour. The form promises
/// the trainer a count before anything is sent, so this has to agree with the
/// server exactly — inclusive bounds, the same cap, the same "empty is not
/// allowed" rule (docs/personal_trainer/09).
void main() {
  OccurrencePreview run({
    required ScheduleRecurrence recurrence,
    List<ScheduleWeekday> days = const [],
    required DateTime start,
    required DateTime end,
  }) {
    return generateOccurrences(
      recurrence: recurrence,
      daysOfWeek: days,
      startDate: start,
      endDate: end,
    );
  }

  group('once', () {
    test('is exactly its start date, whatever the end date says', () {
      final preview = run(
        recurrence: ScheduleRecurrence.once,
        start: DateTime(2026, 8, 5),
        end: DateTime(2026, 12, 31),
      );

      expect(preview.dates, [DateTime(2026, 8, 5)]);
      expect(preview.isValid, isTrue);
    });
  });

  group('daily', () {
    test('includes both bounds', () {
      final preview = run(
        recurrence: ScheduleRecurrence.daily,
        start: DateTime(2026, 8, 5),
        end: DateTime(2026, 8, 8),
      );

      expect(preview.count, 4);
      expect(preview.first, DateTime(2026, 8, 5));
      expect(preview.last, DateTime(2026, 8, 8));
    });

    test('a single-day range is one occurrence, not none', () {
      final preview = run(
        recurrence: ScheduleRecurrence.daily,
        start: DateTime(2026, 8, 5),
        end: DateTime(2026, 8, 5),
      );

      expect(preview.count, 1);
      expect(preview.isValid, isTrue);
    });
  });

  group('weekly', () {
    test('picks only the chosen weekdays', () {
      // 2026-08-03 is a Monday.
      final preview = run(
        recurrence: ScheduleRecurrence.weekly,
        days: [ScheduleWeekday.monday, ScheduleWeekday.thursday],
        start: DateTime(2026, 8, 3),
        end: DateTime(2026, 8, 16),
      );

      expect(preview.dates, [
        DateTime(2026, 8, 3),
        DateTime(2026, 8, 6),
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 13),
      ]);
    });

    test('the order days were picked in does not change the dates', () {
      final inOrder = run(
        recurrence: ScheduleRecurrence.weekly,
        days: [ScheduleWeekday.monday, ScheduleWeekday.thursday],
        start: DateTime(2026, 8, 3),
        end: DateTime(2026, 8, 16),
      );
      final reversed = run(
        recurrence: ScheduleRecurrence.weekly,
        days: [ScheduleWeekday.thursday, ScheduleWeekday.monday],
        start: DateTime(2026, 8, 3),
        end: DateTime(2026, 8, 16),
      );

      expect(reversed.dates, inOrder.dates);
    });

    test('no chosen day means no occurrences, which is a problem to report', () {
      final preview = run(
        recurrence: ScheduleRecurrence.weekly,
        start: DateTime(2026, 8, 3),
        end: DateTime(2026, 8, 16),
      );

      expect(preview.isValid, isFalse);
      expect(preview.problem, OccurrenceProblem.none);
    });

    test('a range with none of the chosen weekdays in it reports the same', () {
      // Tue 4th to Wed 5th contains no Monday.
      final preview = run(
        recurrence: ScheduleRecurrence.weekly,
        days: [ScheduleWeekday.monday],
        start: DateTime(2026, 8, 4),
        end: DateTime(2026, 8, 5),
      );

      expect(preview.problem, OccurrenceProblem.none);
    });
  });

  group('the cap', () {
    test('exactly the maximum is still allowed', () {
      final start = DateTime(2026, 1, 1);
      final preview = run(
        recurrence: ScheduleRecurrence.daily,
        start: start,
        end: start.add(const Duration(days: maxScheduleOccurrences - 1)),
      );

      expect(preview.count, maxScheduleOccurrences);
      expect(preview.isValid, isTrue);
    });

    test('one past it is refused before the request is made', () {
      final start = DateTime(2026, 1, 1);
      final preview = run(
        recurrence: ScheduleRecurrence.daily,
        start: start,
        end: start.add(const Duration(days: maxScheduleOccurrences)),
      );

      expect(preview.count, maxScheduleOccurrences + 1);
      expect(preview.isValid, isFalse);
      expect(preview.problem, OccurrenceProblem.tooMany);
    });
  });

  group('calendar arithmetic', () {
    test('a daily run across a daylight-saving change loses no day', () {
      // Central European DST ends on the last Sunday of October; stepping by
      // a 24-hour Duration instead of a calendar day would either repeat or
      // skip a date here, depending on which way the clock moved.
      final preview = run(
        recurrence: ScheduleRecurrence.daily,
        start: DateTime(2026, 10, 23),
        end: DateTime(2026, 11, 2),
      );

      expect(preview.count, 11);
      expect(preview.dates.map((d) => d.day),
          [23, 24, 25, 26, 27, 28, 29, 30, 31, 1, 2]);
    });

    test('a daily run across a month boundary is continuous', () {
      final preview = run(
        recurrence: ScheduleRecurrence.daily,
        start: DateTime(2026, 1, 30),
        end: DateTime(2026, 2, 2),
      );

      expect(preview.dates, [
        DateTime(2026, 1, 30),
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 1),
        DateTime(2026, 2, 2),
      ]);
    });

    test('a leap day is included like any other', () {
      final preview = run(
        recurrence: ScheduleRecurrence.daily,
        start: DateTime(2028, 2, 27),
        end: DateTime(2028, 3, 1),
      );

      expect(preview.dates.map((d) => '${d.month}-${d.day}'),
          ['2-27', '2-28', '2-29', '3-1']);
    });

    test('the time of day on the bounds is ignored', () {
      final preview = run(
        recurrence: ScheduleRecurrence.daily,
        start: DateTime(2026, 8, 5, 23, 59),
        end: DateTime(2026, 8, 6, 0, 1),
      );

      expect(preview.count, 2);
      expect(preview.first, DateTime(2026, 8, 5));
    });
  });
}
