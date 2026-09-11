import 'program.dart';

/// Dart port of the date arithmetic in `web/src/features/trainer/program.ts`.
///
/// A program's weeks are Monday-anchored and a run always starts on a Monday
/// — the backend enforces both (`ProgramAssignmentRequest`: "must be a Monday,
/// not in the past"). These functions let the assign sheet offer only valid
/// dates and say what the run will cover, instead of finding out from a 400.
///
/// Only the read-and-assign half of `program.ts` is ported. The grid-mutation
/// helpers (`setSlot`, `duplicateWeek`, `copyWeekToAll`, `validateProgram`,
/// `dropOverflowWeeks`) are the editor's, and nothing on mobile edits a grid
/// — porting them would be untested weight carrying a promise the app does
/// not keep.

const int _millisecondsPerDay = 24 * 60 * 60 * 1000;

/// The Monday on or after [from] — [from] itself when it is already a Monday.
/// The time of day is dropped.
DateTime nextOrSameMonday(DateTime from) {
  final day = DateTime(from.year, from.month, from.day);
  final daysPastMonday = day.weekday - DateTime.monday;
  if (daysPastMonday == 0) return day;
  return DateTime(day.year, day.month, day.day + (7 - daysPastMonday));
}

/// Whether a date can start a program run: a Monday, and not in the past.
bool isValidProgramStartDate(DateTime date, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  return day.weekday == DateTime.monday && !day.isBefore(startOfToday);
}

/// The last day of the run, inclusive: start + weeks − 1 day.
DateTime programEndDate(DateTime startDate, int weeksCount) {
  final day = DateTime(startDate.year, startDate.month, startDate.day);
  return DateTime(day.year, day.month, day.day + weeksCount * 7 - 1);
}

/// Which week of the run [today] falls in, 1-based and clamped to the run's
/// length: before it starts reads as week 1, after it ends as the last week.
int currentProgramWeek(DateTime startDate, int weeksCount, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  // Both ends snapped to their Monday first, so the answer counts calendar
  // weeks rather than seven-day blocks — the same `weekStartsOn: 1` the web
  // passes to date-fns.
  final startMonday = _mondayOf(start);
  final todayMonday = _mondayOf(DateTime(now.year, now.month, now.day));
  final diffWeeks =
      ((todayMonday.millisecondsSinceEpoch - startMonday.millisecondsSinceEpoch) /
              (_millisecondsPerDay * 7))
          .round();
  return diffWeeks + 1 < 1
      ? 1
      : (diffWeeks + 1 > weeksCount ? weeksCount : diffWeeks + 1);
}

/// Inverse of [programEndDate] — how many weeks a [start, end] pair spans.
///
/// Needed because an assignment comes back as a date range, not a week count,
/// and the UI wants to say "week 3 of 8".
int weeksBetween(DateTime startDate, DateTime endDate) {
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final end = DateTime(endDate.year, endDate.month, endDate.day);
  final diffDays =
      ((end.millisecondsSinceEpoch - start.millisecondsSinceEpoch) / _millisecondsPerDay)
          .round();
  final weeks = ((diffDays + 1) / 7).round();
  return weeks < 1 ? 1 : weeks;
}

/// Distinct weekdays used across a grid — mirrors the backend's
/// `ProgramSummaryResponse.slotsPerWeek`, for a program loaded in full.
int slotsPerWeek(List<ProgramSlot> workouts) =>
    workouts.map((w) => w.dayOfWeek).toSet().length;

DateTime _mondayOf(DateTime day) =>
    DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));
