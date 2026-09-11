import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/schedule_repository.dart';
import '../domain/schedule.dart';
import 'calendar_controller.dart';

/// How far ahead the client's schedule tab looks. Comfortably inside the
/// backend's 62-day cap, and long enough to cover a typical block.
const int clientUpcomingHorizonDays = 56;

/// One client's schedules — the series, not the occurrences.
final clientSchedulesProvider =
    FutureProvider.family<List<ScheduleSummary>, int>((ref, clientId) {
  return ref.watch(scheduleRepositoryProvider).findSchedulesForClient(clientId);
});

/// What is coming up for one client, oldest first.
///
/// Starts from today rather than from the series' own start: the tab answers
/// "what is next", and last month's occurrences are the workouts tab's story.
final clientUpcomingOccurrencesProvider =
    FutureProvider.family<List<CalendarSession>, int>((ref, clientId) async {
  final today = dateOnly(DateTime.now());
  final occurrences =
      await ref.watch(scheduleRepositoryProvider).findOccurrencesForClient(
            clientId,
            from: today,
            to: today.add(const Duration(days: clientUpcomingHorizonDays)),
          );
  return [...occurrences]..sort((a, b) {
      final byDate = a.scheduledFor.compareTo(b.scheduledFor);
      if (byDate != 0) return byDate;
      final aTime = a.scheduledTime;
      final bTime = b.scheduledTime;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      final byHour = aTime.hour - bTime.hour;
      return byHour != 0 ? byHour : aTime.minute - bTime.minute;
    });
});

/// Cancels a whole series and refreshes what depended on it.
///
/// A function rather than a notifier: there is no state to own here, only a
/// write and the invalidations that follow it — including the calendar, which
/// is showing the same occurrences from the other end.
final cancelScheduleProvider =
    Provider<Future<void> Function(int clientId, int scheduleId)>((ref) {
  return (clientId, scheduleId) async {
    await ref.read(scheduleRepositoryProvider).cancelSchedule(scheduleId);
    ref.invalidate(clientSchedulesProvider(clientId));
    ref.invalidate(clientUpcomingOccurrencesProvider(clientId));
    ref.invalidate(calendarSessionsProvider);
  };
});
