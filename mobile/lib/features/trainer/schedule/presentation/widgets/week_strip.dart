import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../shared/widgets/ds/lifey_card.dart';
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
      child: LifeyCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8, horizontal: AppSpacing.s4),
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
  });

  final DateTime day;
  final DateTime selectedDay;
  final DateTime today;
  final DateFormat weekdayFormat;
  final List<CalendarSession> sessions;
  final ValueChanged<DateTime> onTap;

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final selected = _sameDay(day, selectedDay);
    final isToday = _sameDay(day, today);
    final ofDay = sessions.where((s) => _sameDay(s.scheduledFor.toLocal(), day)).toList();

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: AppRadius.controlAll,
        onTap: () => onTap(day),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(weekdayFormat.format(day), style: t.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: p.text2)),
              const SizedBox(height: AppSpacing.s4),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? primary : Colors.transparent,
                  border: isToday && !selected ? Border.all(color: primary, width: 1.5) : null,
                ),
                child: Text(
                  '${day.day}',
                  style: t.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: selected ? onPrimary : p.text),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              // Up to three dots: past that the count stops being readable at
              // this size, and the agenda below is the place for the detail.
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final session in ofDay.take(3))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: occurrenceStatusColor(context, session.status)),
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
