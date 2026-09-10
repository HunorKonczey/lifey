import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/trainer/programs/domain/program.dart';
import 'package:lifey/features/trainer/programs/domain/program_dates.dart';
import 'package:lifey/features/trainer/schedule/domain/schedule.dart';

/// Port of the date-math half of `web/src/features/trainer/program.test.ts`,
/// case for case. A program run is Monday-anchored on both sides, and the
/// assign sheet promises a range before the request goes out — so this has to
/// land on the same dates the web does.
void main() {
  group('nextOrSameMonday', () {
    test('returns the same date when it is already a Monday', () {
      // 2026-07-13 is a Monday.
      expect(nextOrSameMonday(DateTime(2026, 7, 13, 15)), DateTime(2026, 7, 13));
    });

    test('returns the following Monday for any other day', () {
      expect(nextOrSameMonday(DateTime(2026, 7, 15)), DateTime(2026, 7, 20));
    });

    test('a Sunday rolls to the very next day', () {
      expect(nextOrSameMonday(DateTime(2026, 7, 19)), DateTime(2026, 7, 20));
    });

    test('strips the time of day', () {
      expect(nextOrSameMonday(DateTime(2026, 7, 13, 23, 59)).hour, 0);
    });
  });

  group('isValidProgramStartDate', () {
    final today = DateTime(2026, 7, 13); // a Monday

    test('accepts today when today is a Monday', () {
      expect(
        isValidProgramStartDate(DateTime(2026, 7, 13), today: today),
        isTrue,
      );
    });

    test('rejects a non-Monday', () {
      expect(
        isValidProgramStartDate(DateTime(2026, 7, 14), today: today),
        isFalse,
      );
    });

    test('rejects a Monday in the past', () {
      expect(
        isValidProgramStartDate(DateTime(2026, 7, 6), today: today),
        isFalse,
      );
    });

    test('accepts a future Monday', () {
      expect(
        isValidProgramStartDate(DateTime(2026, 7, 20), today: today),
        isTrue,
      );
    });

    test('the time of day on "today" does not disqualify today', () {
      expect(
        isValidProgramStartDate(
          DateTime(2026, 7, 13),
          today: DateTime(2026, 7, 13, 23, 59),
        ),
        isTrue,
      );
    });
  });

  group('programEndDate', () {
    test('is start + weeks - 1 day', () {
      expect(programEndDate(DateTime(2026, 7, 13), 2), DateTime(2026, 7, 26));
    });

    test('a single week ends six days later', () {
      expect(programEndDate(DateTime(2026, 7, 13), 1), DateTime(2026, 7, 19));
    });

    test('a full twelve weeks lands on a Sunday', () {
      final end = programEndDate(DateTime(2026, 7, 13), programMaxWeeks);
      expect(end.weekday, DateTime.sunday);
    });
  });

  group('currentProgramWeek', () {
    final start = DateTime(2026, 7, 13); // a Monday

    test('is week 1 on the start date', () {
      expect(
        currentProgramWeek(start, 4, today: DateTime(2026, 7, 13, 12)),
        1,
      );
    });

    test('is week 1 anywhere within the first week', () {
      expect(
        currentProgramWeek(start, 4, today: DateTime(2026, 7, 19, 12)),
        1,
      );
    });

    test('advances to week 2 on the second Monday', () {
      expect(
        currentProgramWeek(start, 4, today: DateTime(2026, 7, 20, 12)),
        2,
      );
    });

    test('clamps to the last week after the run has ended', () {
      expect(
        currentProgramWeek(start, 4, today: DateTime(2026, 12, 1, 12)),
        4,
      );
    });

    test('clamps to 1 before the run has started', () {
      expect(
        currentProgramWeek(start, 4, today: DateTime(2026, 7, 1, 12)),
        1,
      );
    });
  });

  group('weeksBetween', () {
    test('is the exact inverse of programEndDate', () {
      final start = DateTime(2026, 7, 13);
      for (final weeks in [1, 2, 4, 12]) {
        expect(weeksBetween(start, programEndDate(start, weeks)), weeks);
      }
    });

    test('a single week is 1', () {
      expect(weeksBetween(DateTime(2026, 7, 13), DateTime(2026, 7, 19)), 1);
    });

    test('four weeks matches the web regression case', () {
      expect(weeksBetween(DateTime(2026, 7, 13), DateTime(2026, 8, 9)), 4);
    });

    test('a run spanning a daylight-saving change still counts whole weeks', () {
      // Central European DST ends inside this range; counting by elapsed
      // milliseconds alone would be an hour short of four weeks.
      final start = DateTime(2026, 10, 12);
      expect(weeksBetween(start, programEndDate(start, 4)), 4);
    });
  });

  group('slotsPerWeek', () {
    ProgramSlot slot(int week, ScheduleWeekday day) => ProgramSlot(
          weekNumber: week,
          dayOfWeek: day,
          templateId: 1,
          templateName: 'Push day',
        );

    test('counts distinct weekdays across the whole grid', () {
      final workouts = [
        slot(1, ScheduleWeekday.monday),
        slot(1, ScheduleWeekday.thursday),
        slot(2, ScheduleWeekday.monday),
        slot(2, ScheduleWeekday.thursday),
      ];

      expect(slotsPerWeek(workouts), 2);
    });

    test('is zero for an empty grid', () {
      expect(slotsPerWeek(const []), 0);
    });
  });

  group('reading a week out of a grid', () {
    test('slots come back in weekday order, whatever order they arrived in', () {
      const program = Program(
        id: 1,
        name: 'Base',
        weeksCount: 2,
        workouts: [
          ProgramSlot(
            weekNumber: 1,
            dayOfWeek: ScheduleWeekday.thursday,
            templateId: 2,
            templateName: 'Pull day',
          ),
          ProgramSlot(
            weekNumber: 1,
            dayOfWeek: ScheduleWeekday.monday,
            templateId: 1,
            templateName: 'Push day',
          ),
          ProgramSlot(
            weekNumber: 2,
            dayOfWeek: ScheduleWeekday.monday,
            templateId: 1,
            templateName: 'Push day',
          ),
        ],
      );

      expect(
        program.slotsOfWeek(1).map((s) => s.dayOfWeek),
        [ScheduleWeekday.monday, ScheduleWeekday.thursday],
      );
    });

    test('a week with nothing in it comes back empty, not missing', () {
      const program = Program(
        id: 1,
        name: 'Base',
        weeksCount: 3,
        workouts: [
          ProgramSlot(
            weekNumber: 1,
            dayOfWeek: ScheduleWeekday.monday,
            templateId: 1,
            templateName: 'Push day',
          ),
        ],
      );

      // A rest week is a real answer, and the detail screen says so.
      expect(program.slotsOfWeek(2), isEmpty);
    });
  });
}
