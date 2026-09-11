import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../domain/schedule.dart';

/// A schedule's rule in a sentence a person can read: "Every Mon and Thu ·
/// 18:00 · Jul 7 – Oct 6" (frames F3 and F4).
///
/// Built from pieces joined with a separator rather than from one ICU string
/// per shape, because the shapes multiply — three recurrences × with or
/// without a time × one day or several — and a translator should not have to
/// carry a dozen near-identical sentences.
String recurrenceSummary(
  AppLocalizations l10n,
  String locale, {
  required ScheduleRecurrence recurrence,
  required List<ScheduleWeekday> daysOfWeek,
  required DateTime startDate,
  required DateTime endDate,
  ScheduleTime? timeOfDay,
}) {
  final dateFormat = DateFormat.MMMd(locale);
  final parts = <String>[
    _rule(l10n, locale, recurrence, daysOfWeek),
    if (timeOfDay != null) formatScheduleTime(timeOfDay),
    if (recurrence == ScheduleRecurrence.once)
      dateFormat.format(startDate)
    else
      l10n.trainerDateRangeLabel(
        dateFormat.format(startDate),
        dateFormat.format(endDate),
      ),
  ];
  return parts.join(' · ');
}

String _rule(
  AppLocalizations l10n,
  String locale,
  ScheduleRecurrence recurrence,
  List<ScheduleWeekday> daysOfWeek,
) {
  switch (recurrence) {
    case ScheduleRecurrence.once:
      return l10n.trainerRecurrenceOnceLabel;
    case ScheduleRecurrence.daily:
      return l10n.trainerRecurrenceDailyLabel;
    case ScheduleRecurrence.weekly:
      if (daysOfWeek.isEmpty) return l10n.trainerRecurrenceWeeklyLabel;
      return l10n.trainerRecurrenceOnDaysLabel(formatWeekdays(locale, daysOfWeek));
  }
}

/// "Mon, Thu" — short weekday names in calendar order, whatever order they
/// were selected in.
String formatWeekdays(String locale, List<ScheduleWeekday> days) {
  final sorted = [...days]..sort((a, b) => a.isoNumber.compareTo(b.isoNumber));
  final format = DateFormat.E(locale);
  return sorted.map((day) => format.format(_anyDateOn(day))).join(', ');
}

/// "18:00". Deliberately 24-hour and locale-independent: this is a wall-clock
/// value the trainer typed, and the API round-trips it as `HH:mm`.
String formatScheduleTime(ScheduleTime time) => time.apiValue;

/// A throwaway date that falls on [day], for the weekday formatter. 2024-01-01
/// was a Monday, so adding the ISO number minus one lands on the right day.
DateTime _anyDateOn(ScheduleWeekday day) =>
    DateTime(2024, 1, day.isoNumber);
