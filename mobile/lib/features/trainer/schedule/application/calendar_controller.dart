import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/schedule_repository.dart';
import '../domain/schedule.dart';

/// Monday of the week [date] falls in, at local midnight.
DateTime weekStartOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// A date with the time stripped, so two "same day" values compare equal.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Occurrences across every client in a date range.
///
/// Keyed by the range so the agenda (a week) and the month overview (a month)
/// can each hold their own answer instead of evicting one another.
final calendarSessionsProvider = FutureProvider.family<List<CalendarSession>,
    ({DateTime from, DateTime to})>((ref, range) {
  assert(
    range.to.difference(range.from).inDays <= maxCalendarRangeDays,
    'The backend refuses a range longer than $maxCalendarRangeDays days',
  );
  return ref
      .watch(scheduleRepositoryProvider)
      .findOccurrences(from: range.from, to: range.to);
});

/// Which week the agenda is showing. Monday-anchored, in memory only — the
/// calendar opens on the current week every time it is entered, which is
/// where a trainer's question ("what is today, what is this week") starts.
class CalendarWeekController extends Notifier<DateTime> {
  @override
  DateTime build() => weekStartOf(DateTime.now());

  void showWeekOf(DateTime date) => state = weekStartOf(date);

  void previousWeek() => state = state.subtract(const Duration(days: 7));

  void nextWeek() => state = state.add(const Duration(days: 7));

  void today() => state = weekStartOf(DateTime.now());
}

final calendarWeekControllerProvider =
    NotifierProvider<CalendarWeekController, DateTime>(
  CalendarWeekController.new,
);

/// Which clients the calendar is narrowed to. Empty means everyone — the
/// distinction matters, because "no clients selected" would show an empty
/// calendar and read as "nothing scheduled" (frame F5).
class CalendarClientFilterController extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void toggle(int clientId) {
    final next = {...state};
    if (!next.remove(clientId)) next.add(clientId);
    state = next;
  }

  void clear() => state = const {};

  bool isVisible(int clientId) => state.isEmpty || state.contains(clientId);
}

final calendarClientFilterProvider =
    NotifierProvider<CalendarClientFilterController, Set<int>>(
  CalendarClientFilterController.new,
);

/// Occurrences of one day, ordered the way the agenda reads them: timed ones
/// first and in clock order, untimed ones after, under their own divider
/// (frame F1).
List<CalendarSession> sessionsOfDay(
  List<CalendarSession> sessions,
  DateTime day,
) {
  final target = dateOnly(day);
  final ofDay = sessions
      .where((s) => dateOnly(s.scheduledFor.toLocal()) == target)
      .toList();
  ofDay.sort((a, b) {
    final aTime = a.scheduledTime;
    final bTime = b.scheduledTime;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    final byHour = aTime.hour - bTime.hour;
    return byHour != 0 ? byHour : aTime.minute - bTime.minute;
  });
  return ofDay;
}
