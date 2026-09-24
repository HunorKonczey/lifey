import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../charts/bar_chart.dart';
import '../../charts/chart_math.dart';
import '../lifey_card.dart';
import 'gallery_section.dart';

/// Gallery sections for the v2 charts (docs/redesign/77-mobile-redesign-plan.md
/// R0.13–R0.14).
final List<GallerySection> chartSections = [
  GallerySection(
    title: 'Bar chart',
    source: 'Lifey 1 › This week · Lifey 4–5 › Workouts · last 30 days · R0.13',
    builder: (_) => const _BarChartSection(),
  ),
];

bool _hu(BuildContext context) => Localizations.localeOf(context).languageCode == 'hu';

class _BarChartSection extends StatelessWidget {
  const _BarChartSection();

  @override
  Widget build(BuildContext context) {
    final hu = _hu(context);
    final f = LifeyFormat.of(context);
    final m = context.metricColors;
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    // The canvas week: Fri 18 → Thu 24 Sep, today (Thu) half-logged.
    final today = DateTime(2026, 9, 24, 12);
    const kcal = <double>[1680, 1850, 1471, 1759, 1910, 1601, 621];
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final avg = averageExcludingPartialToday(
      [for (var i = 0; i < 7; i++) (day: days[i], value: kcal[i])],
      today,
      ignoreZero: true,
    )!;

    // Workouts per week, last five weeks (canvas: 4, 5, 6, 4, 3).
    const weeks = <double>[4, 5, 6, 4, 3];
    final weekStarts = [for (var i = 4; i >= 0; i--) today.subtract(Duration(days: 7 * i))];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LifeyCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Expanded(child: Text(hu ? 'Ezen a héten' : 'This week', style: t.titleMedium!.copyWith(fontSize: 15))),
              Text.rich(TextSpan(
                style: t.labelMedium!.copyWith(color: p.text2),
                children: [
                  TextSpan(text: hu ? 'átl. ' : 'avg '),
                  TextSpan(text: f.kcal(avg), style: TextStyle(color: p.text, fontWeight: FontWeight.w800)),
                  const TextSpan(text: ' kcal'),
                ],
              )),
            ]),
            const SizedBox(height: 14),
            LifeyBarChart(
              color: m.calories,
              goal: 2360,
              bars: [
                for (var i = 0; i < 7; i++)
                  BarDatum(
                    label: f.weekdayNarrow(days[i]),
                    value: kcal[i],
                    highlighted: i == 6,
                    semanticsLabel: '${f.dayLabel(days[i])}, ${f.kcal(kcal[i])} kcal',
                  ),
              ],
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          'Average ${f.kcal(avg)} excludes today\'s partial ${f.kcal(kcal.last)} (plan §9 risk 5).',
          style: t.bodySmall!.copyWith(color: p.text3),
        ),
        const GalleryCaption('Weekly counts — integer axis with headroom (6 → 7)'),
        LifeyCard.hero(
          child: LifeyBarChart(
            color: m.protein,
            height: 150,
            barGap: 14,
            integer: true,
            bars: [
              for (var i = 0; i < 5; i++)
                BarDatum(
                  label: f.shortDate(weekStarts[i]),
                  value: weeks[i],
                  highlighted: i == 4,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
