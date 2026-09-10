import 'schedule.dart';

/// Dart port of the backend's `OccurrenceGenerator`
/// (docs/personal_trainer/09-utemezett-edzesek-domain-backend.md).
///
/// The server materializes every occurrence the moment a schedule is created;
/// this exists so the form can say **before** submitting how many dates that
/// will be and where they end ("this creates 12 sessions, Aug 5 – Oct 28",
/// frame F4). It must therefore agree with the server exactly — same
/// inclusive bounds, same cap, same "empty is not allowed" rule.
///
/// No time zone anywhere: like the backend, this is pure date arithmetic on
/// local calendar days.

/// Sanity cap. Daily for ~3 months tops out near 92; the backend refuses
/// anything past this, so the form stops the trainer here rather than letting
/// the request fail.
const int maxScheduleOccurrences = 100;

/// Why a recurrence cannot be turned into occurrences.
enum OccurrenceProblem {
  /// The rule matches no day in the range — e.g. "every Monday" over a range
  /// with no Monday in it.
  none,

  /// More dates than the backend will accept.
  tooMany,
}

/// The dates a schedule would create, plus what is wrong if it would create
/// nothing usable.
class OccurrencePreview {
  const OccurrencePreview(this.dates, {this.problem});

  final List<DateTime> dates;
  final OccurrenceProblem? problem;

  bool get isValid => problem == null && dates.isNotEmpty;
  int get count => dates.length;
  DateTime? get first => dates.isEmpty ? null : dates.first;
  DateTime? get last => dates.isEmpty ? null : dates.last;
}

/// Every date the given rule produces, inclusive of both bounds.
///
/// [endDate] is ignored for [ScheduleRecurrence.once], exactly as the backend
/// ignores it: a one-off happens on its start date and nowhere else.
OccurrencePreview generateOccurrences({
  required ScheduleRecurrence recurrence,
  required List<ScheduleWeekday> daysOfWeek,
  required DateTime startDate,
  required DateTime endDate,
}) {
  final start = _dateOnly(startDate);
  final end = recurrence == ScheduleRecurrence.once ? start : _dateOnly(endDate);

  final dates = <DateTime>[];
  switch (recurrence) {
    case ScheduleRecurrence.once:
      dates.add(start);
    case ScheduleRecurrence.daily:
      for (var day = start; !day.isAfter(end); day = _nextDay(day)) {
        dates.add(day);
      }
    case ScheduleRecurrence.weekly:
      final selected = daysOfWeek.map((d) => d.isoNumber).toSet();
      for (var day = start; !day.isAfter(end); day = _nextDay(day)) {
        if (selected.contains(day.weekday)) dates.add(day);
      }
  }

  if (dates.isEmpty) {
    return const OccurrencePreview([], problem: OccurrenceProblem.none);
  }
  if (dates.length > maxScheduleOccurrences) {
    return OccurrencePreview(dates, problem: OccurrenceProblem.tooMany);
  }
  return OccurrencePreview(dates);
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Steps a calendar day, not 24 hours: adding a `Duration` would land an hour
/// early or late across a daylight-saving boundary and silently drop or
/// duplicate a date.
DateTime _nextDay(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1);
