import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../domain/schedule.dart';
import 'occurrence_status_chip.dart';

/// Below this width the month is drawn as dot density only; at or above it
/// there is room to name what is on each day (frame F2: the full grid is for
/// landscape and tablets, the reduced one is what fits a portrait phone).
///
/// A width threshold rather than an orientation check: a landscape phone and
/// a portrait tablet are the same problem, and only one of them is an
/// orientation.
const double monthGridMinWidth = 600;

/// The month at a glance (frame F2).
///
/// Secondary on purpose. The month grid is the web's primary view and it does
/// not survive a phone: thirty-odd cells with several events each is a
/// picture of a month, not a tool for working through one. Tapping a day
/// hands back to the agenda, which is where the detail lives.
class MonthOverview extends StatelessWidget {
  const MonthOverview({
    super.key,
    required this.month,
    required this.sessions,
    required this.onSelectDay,
  });

  /// Any date inside the month being shown.
  final DateTime month;
  final List<CalendarSession> sessions;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final wide = MediaQuery.sizeOf(context).width >= monthGridMinWidth;

    final firstOfMonth = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Leading blanks so the 1st lands under its weekday column.
    final leadingBlanks = firstOfMonth.weekday - DateTime.monday;
    final today = DateTime.now();

    final byDay = <int, List<CalendarSession>>{};
    for (final session in sessions) {
      final local = session.scheduledFor.toLocal();
      if (local.year != month.year || local.month != month.month) continue;
      byDay.putIfAbsent(local.day, () => []).add(session);
    }

    final weekdayFormat = DateFormat.E(locale);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    weekdayFormat.format(DateTime(2024, 1, i + 1)),
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: wide ? 1.0 : 0.78,
          children: [
            for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
            for (var day = 1; day <= daysInMonth; day++)
              _DayCell(
                date: DateTime(month.year, month.month, day),
                sessions: byDay[day] ?? const [],
                isToday: today.year == month.year &&
                    today.month == month.month &&
                    today.day == day,
                wide: wide,
                onTap: onSelectDay,
              ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.sessions,
    required this.isToday,
    required this.wide,
    required this.onTap,
  });

  final DateTime date;
  final List<CalendarSession> sessions;
  final bool isToday;
  final bool wide;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    return Semantics(
      button: true,
      // The dots carry the density visually; spoken, the day needs its date
      // and a count, or it is just a number with nothing attached.
      label: '${DateFormat.MMMd(locale).format(date)}, '
          '${l10n.trainerProgramSessionCountLabel(sessions.length)}',
      child: Material(
        color: sessions.isEmpty ? Colors.transparent : scheme.surfaceContainer,
        borderRadius: AppRadius.smAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(date),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: isToday
                ? BoxDecoration(
                    borderRadius: AppRadius.smAll,
                    border: Border.all(color: scheme.tertiary, width: 1.5),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: wide
                      ? _Names(sessions: sessions)
                      : _Dots(sessions: sessions),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The reduced form: density, not content.
class _Dots extends StatelessWidget {
  const _Dots({required this.sessions});

  final List<CalendarSession> sessions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: [
        for (final session in sessions.take(6))
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: occurrenceStatusColor(context, session.status),
            ),
          ),
      ],
    );
  }
}

/// The wide form: the first couple of names, and a count for the rest.
class _Names extends StatelessWidget {
  const _Names({required this.sessions});

  final List<CalendarSession> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final session in sessions.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: occurrenceStatusColor(context, session.status)
                    .withValues(alpha: 0.18),
                borderRadius: AppRadius.smAll,
              ),
              child: Text(
                session.templateName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (sessions.length > 2)
          Text(
            '+${sessions.length - 2}',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 9,
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
