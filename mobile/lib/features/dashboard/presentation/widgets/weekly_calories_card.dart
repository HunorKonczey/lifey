import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/format/emphasis.dart';
import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/charts/bar_chart.dart';
import '../../../../shared/widgets/charts/chart_math.dart';
import '../../../../shared/widgets/charts/time_series_chart.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';

/// "This week" — the last seven days of calories as a bar chart (design
/// system v2; docs/redesign/77-mobile-redesign-plan.md R1.5, canvas Lifey 1:
/// "Diagram, ami olvasható").
///
/// Fixes the old sparkline: a Y axis (top, half, 0), a dashed line at the
/// calorie goal, today's bar in full colour and the others at 45 %, weekday
/// letters under the bars — and an average in the header that **leaves out
/// today**, so a half-logged morning no longer drags the line down. Days with
/// nothing logged are empty columns and don't count towards the average
/// (0 kcal means "not logged", not "ate nothing").
///
/// [points] are the seven days, oldest first, today last.
class WeeklyCaloriesCard extends StatelessWidget {
  const WeeklyCaloriesCard({
    super.key,
    required this.points,
    this.goal,
    this.now,
  });

  final List<TimeSeriesPoint> points;

  /// The daily calorie goal, drawn as the dashed line; null draws none.
  final int? goal;

  /// The clock — injectable for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final color = context.metricColors.calories;
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);

    bool isToday(DateTime d) => DateTime(d.year, d.month, d.day) == today;

    final average = averageExcludingPartialToday(
      [for (final pt in points) (day: pt.date, value: pt.value > 0 ? pt.value : null)],
      clock,
    );

    final bars = [
      for (final pt in points)
        BarDatum(
          label: f.weekdayNarrow(pt.date),
          value: pt.value > 0 ? pt.value : null,
          highlighted: isToday(pt.date),
          semanticsLabel: l10n.dashboardWeekBarSemantics(
            DateFormat.EEEE(f.locale).format(pt.date),
            f.kcal(pt.value),
          ),
        ),
    ];

    final captionStyle = t.bodySmall!.copyWith(fontWeight: FontWeight.w600, height: 1, color: p.text2);

    return LifeyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.dashboardWeekTitle,
                    style: t.bodyMedium!.copyWith(fontWeight: FontWeight.w700, height: 1, color: p.text),
                  ),
                ),
              ),
              if (average != null) ...[
                const SizedBox(width: AppSpacing.s8),
                Text.rich(
                  Emphasis.span(
                    l10n.dashboardWeekAvg(Emphasis.marker(0)),
                    [f.kcal(average)],
                    captionStyle.copyWith(color: p.text, fontWeight: FontWeight.w700),
                  ),
                  style: captionStyle,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          LifeyBarChart(
            bars: bars,
            color: color,
            goal: goal?.toDouble(),
            semanticsLabel: average == null
                ? l10n.dashboardWeekTitle
                : l10n.dashboardWeekChartSemantics(f.kcal(average)),
          ),
        ],
      ),
    );
  }
}
