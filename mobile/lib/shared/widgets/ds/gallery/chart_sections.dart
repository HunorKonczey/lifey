import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../charts/bar_chart.dart';
import '../../charts/chart_math.dart';
import '../../charts/time_series_chart.dart';
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
  GallerySection(
    title: 'Line chart',
    source: 'Lifey 4 › Weight 30 d · Lifey 5 › Stats steps · R0.14',
    builder: (_) => const _LineChartSection(),
  ),
];

/// The canvas weight month: 65.9 kg drifting to 64.5 kg with daily noise.
const _weights = <double>[
  65.9, 65.8, 65.9, 65.7, 65.8, 65.6, 65.6, 65.5, 65.3, 65.4, 65.2, 65.3, 65.1, 65.0, 65.1,
  64.9, 64.8, 64.9, 64.7, 64.8, 64.7, 64.6, 64.8, 64.6, 64.7, 64.6, 64.9, 64.6, 64.6, 64.5,
];

class _LineChartSection extends StatelessWidget {
  const _LineChartSection();

  @override
  Widget build(BuildContext context) {
    final hu = _hu(context);
    final f = LifeyFormat.of(context);
    final m = context.metricColors;
    final today = DateTime(2026, 9, 24);
    final points = [
      for (var i = 0; i < _weights.length; i++)
        TimeSeriesPoint(date: today.subtract(Duration(days: _weights.length - 1 - i)), value: _weights[i]),
    ];
    // Trailing 7-day mean — the real series comes from docs/76's trend.
    final trend = [
      for (var i = 0; i < points.length; i++)
        () {
          final from = i < 6 ? 0 : i - 6;
          final window = _weights.sublist(from, i + 1);
          return window.reduce((a, b) => a + b) / window.length;
        }(),
    ];
    final steps = [
      for (var i = 0; i < 30; i++)
        TimeSeriesPoint(date: today.subtract(Duration(days: 29 - i)), value: 3140 + ((i * 3779) % 9472).toDouble()),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LifeyCard.hero(
          child: TimeSeriesChart(
            points: points,
            trendValues: trend,
            trendStyle: TrendStyle.dotted,
            accentColor: m.weight,
            height: 172,
            gradientFill: true,
            showPoints: false,
            highlightLast: true,
            axisLabelBuilder: (v) => f.weight(v),
            dateLabelBuilder: f.shortDate,
            valueLabelBuilder: (v) => '${f.weight(v)} kg',
            legend: (daily: hu ? 'Napi' : 'Daily', trend: hu ? '7 napos átlag' : '7-day average'),
          ),
        ),
        const GalleryCaption('From zero — steps, with the goal line'),
        LifeyCard.hero(
          child: TimeSeriesChart(
            points: steps,
            accentColor: m.steps,
            height: 172,
            yFromZero: true,
            goalValue: 10000,
            gradientFill: true,
            showPoints: false,
            highlightLast: true,
            axisLabelBuilder: f.compactAxis,
            dateLabelBuilder: f.shortDate,
            valueLabelBuilder: (v) => f.integer(v),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          'The weight canvas makes the daily line the hero and the average dotted — the reverse of '
          'docs/76 D-W3. Both are TrendStyle options; R4.2 decides (plan §10 Q4).',
          style: Theme.of(context).textTheme.bodySmall!.copyWith(color: context.palette.text3),
        ),
      ],
    );
  }
}

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
