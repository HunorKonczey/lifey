import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/lifey_card.dart';
import '../../domain/schedule.dart';
import '../../../../../shared/widgets/ds/tinted_chip.dart';
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
    final t = Theme.of(context).textTheme;
    final p = context.palette;
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.s24),
      child: LifeyCard(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Column(
          children: [
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        weekdayFormat.format(DateTime(2024, 1, i + 1)),
                        style: t.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: p.text2),
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
              // Taller cells as the text grows: the day number scales, the dots do not.
              childAspectRatio: (wide ? 1.0 : 0.78) / MediaQuery.textScalerOf(context).scale(1),
              children: [
                for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
                for (var day = 1; day <= daysInMonth; day++)
                  _DayCell(
                    date: DateTime(month.year, month.month, day),
                    sessions: byDay[day] ?? const [],
                    isToday: today.year == month.year && today.month == month.month && today.day == day,
                    wide: wide,
                    onTap: onSelectDay,
                  ),
              ],
            ),
          ],
        ),
      ),
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
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final primary = Theme.of(context).colorScheme.primary;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final radius = BorderRadius.circular(AppRadius.nested(AppRadius.control, AppSpacing.s4));

    return Semantics(
      button: true,
      // The dots carry the density visually; spoken, the day needs its date
      // and a count, or it is just a number with nothing attached.
      label: '${DateFormat.MMMd(locale).format(date)}, '
          '${l10n.trainerProgramSessionCountLabel(sessions.length)}',
      child: Material(
        color: sessions.isEmpty ? Colors.transparent : p.nested,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(date),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: isToday
                ? BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: primary, width: 1.5),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${date.day}', style: t.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: p.text)),
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
    final t = Theme.of(context).textTheme;
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final session in sessions.take(2))
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: occurrenceStatusColor(context, session.status).withValues(alpha: TintedChip.tintAlpha(Theme.of(context).brightness)),
                borderRadius: AppRadius.tagAll,
              ),
              child: Text(
                session.templateName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: p.text),
              ),
            ),
          ),
        if (sessions.length > 2)
          Text(
            '+${sessions.length - 2}',
            style: t.labelSmall?.copyWith(color: p.text2),
          ),
      ],
    );
  }
}
