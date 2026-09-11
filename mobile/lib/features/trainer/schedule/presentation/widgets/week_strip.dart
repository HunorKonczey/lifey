import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../domain/schedule.dart';
import 'occurrence_status_chip.dart';

/// Seven days across the top of the calendar, each carrying a dot when
/// something is scheduled on it (frame F1).
///
/// Horizontal drag moves a week. Today is marked whether or not it is the
/// selected day, because "where am I" and "what am I looking at" are two
/// different questions and the trainer asks both.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.weekStart,
    required this.selectedDay,
    required this.sessions,
    required this.onSelectDay,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final List<CalendarSession> sessions;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final weekdayFormat = DateFormat.E(locale);
    final today = DateTime.now();

    return GestureDetector(
      // A drag, not a PageView: the strip is seven fixed cells and swapping
      // the week under them is cheaper than paging a scrollable.
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 100) onPreviousWeek();
        if (velocity < -100) onNextWeek();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        color: Colors.transparent,
        child: Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: _DayCell(
                  day: DateTime(weekStart.year, weekStart.month, weekStart.day + i),
                  selectedDay: selectedDay,
                  today: today,
                  weekdayFormat: weekdayFormat,
                  sessions: sessions,
                  onTap: onSelectDay,
                  scheme: scheme,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selectedDay,
    required this.today,
    required this.weekdayFormat,
    required this.sessions,
    required this.onTap,
    required this.scheme,
  });

  final DateTime day;
  final DateTime selectedDay;
  final DateTime today;
  final DateFormat weekdayFormat;
  final List<CalendarSession> sessions;
  final ValueChanged<DateTime> onTap;
  final ColorScheme scheme;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final selected = _sameDay(day, selectedDay);
    final isToday = _sameDay(day, today);
    final ofDay = sessions
        .where((s) => _sameDay(s.scheduledFor.toLocal(), day))
        .toList();

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: () => onTap(day),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                weekdayFormat.format(day),
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? scheme.tertiary : Colors.transparent,
                  border: isToday && !selected
                      ? Border.all(color: scheme.tertiary, width: 1.5)
                      : null,
                ),
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected ? scheme.onTertiary : scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Up to three dots: past that the count stops being readable at
              // this size, and the agenda below is the place for the detail.
              SizedBox(
                height: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final session in ofDay.take(3))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: occurrenceStatusColor(context, session.status),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
