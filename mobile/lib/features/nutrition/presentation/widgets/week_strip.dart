import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/progress_ring.dart';
import '../../domain/meal_days.dart';

/// The Meals tab's seven-day strip: weekday, date and a small calorie ring
/// for each of the last seven days; the selected day sits in a primary-outlined
/// pill (docs/redesign/77-mobile-redesign-plan.md R2.2; canvas Lifey 2 › 2.1
/// "Heti szalag a Today / Week / All szűrő helyett").
///
/// A ring is that day's kcal over the calorie [goal]; without a goal the
/// rings stay empty (there is no "full" to compare with) and the day still
/// shows what it ate to screen readers. The strip is the only day picker —
/// older days live in the "All meals" screen.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.kcalByDay,
    required this.onSelect,
    this.goal,
  });

  /// [lastSevenDays], oldest first.
  final List<DateTime> days;

  /// One of [days] (local midnight).
  final DateTime selected;

  /// Calories eaten per local calendar day; a missing day counts 0.
  final Map<DateTime, double> kcalByDay;
  final int? goal;
  final ValueChanged<DateTime> onSelect;

  /// The cell height of the canvas.
  static const double cellHeight = 72;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, day) in days.indexed) ...[
          if (i > 0) const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: _DayCell(
              day: day,
              selected: day == dateOnly(selected),
              kcal: kcalByDay[day] ?? 0,
              goal: goal,
              onTap: () => onSelect(day),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.kcal,
    required this.goal,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final double kcal;
  final int? goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = LifeyFormat.of(context);
    final l10n = AppLocalizations.of(context)!;
    final primary = Theme.of(context).colorScheme.primary;
    final radius = BorderRadius.circular(AppRadius.control);
    final hasGoal = goal != null && goal! > 0;

    return Semantics(
      button: true,
      selected: selected,
      label: l10n.weekStripDaySemantics(f.shortDayLabel(day), f.kcal(kcal)),
      excludeSemantics: true,
      child: Material(
        color: selected ? p.nested : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            height: WeekStrip.cellHeight,
            decoration: selected
                ? BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: primary, width: 1.5),
                  )
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  f.weekdayShort(day),
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(height: 1, fontWeight: FontWeight.w600, color: selected ? primary : p.text3),
                ),
                const SizedBox(height: AppSpacing.s4),
                ProgressRing(
                  size: 30,
                  progress: hasGoal ? kcal / goal! : 0,
                  color: context.metricColors.calories,
                  child: Text(
                    '${day.day}',
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(height: 1, fontWeight: FontWeight.w800, color: selected ? p.text : p.text2, fontFeatures: AppType.tabular),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
