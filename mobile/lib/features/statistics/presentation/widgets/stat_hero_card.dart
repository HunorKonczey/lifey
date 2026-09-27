import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/entitlements/entitlement_providers.dart';
import '../../../../core/entitlements/paywall_navigation.dart';
import '../../../../core/entitlements/paywall_trigger.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/charts/bar_chart.dart';
import '../../../../shared/widgets/charts/stats_range.dart';
import '../../../../shared/widgets/charts/time_series_chart.dart';
import '../../../../shared/widgets/ds/delta_chip.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/lifey_segmented.dart';
import '../../../../shared/widgets/ds/metric_value.dart';
import '../../../../shared/widgets/ds/tinted_chip.dart';
import '../../../settings/application/settings_controller.dart';
import '../../../settings/domain/user_settings.dart';
import '../../../weight/domain/weight_trend.dart';
import '../../application/stat_chart_data.dart';
import '../../application/stat_metric_controller.dart';
import '../../application/stats_range_controller.dart';
import '../../domain/metric_summary.dart';
import '../../domain/stat_metric.dart';
import '../stat_bars.dart';
import '../stat_format.dart';

/// The statistics hero card (canvas Lifey 4 › 5; docs/redesign/77-mobile-
/// redesign-plan.md R4.6): what the metric was over the range at 64 px, how it
/// moved against the period before, the chart that fits the metric (days as
/// bars, weeks as bars, or a line). The range switcher ([StatRangeSwitcher])
/// sits below the side stats, at thumb reach.
class StatHeroCard extends ConsumerWidget {
  const StatHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = ref.watch(statMetricControllerProvider);
    final range = ref.watch(statsRangeControllerProvider);
    final series = ref.watch(statCurrentSeriesProvider);
    final summary = ref.watch(statSummaryProvider);
    final fmt = StatFormat(context);

    return LifeyCard.hero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...series.when(
            data: (data) {
              final s = summary.value;
              if (s == null || s.hero == null || data.isEmpty) {
                return [_EmptyRange(fmt: fmt, range: range)];
              }
              return [
                _HeroHeader(metric: metric, range: range, summary: s, fmt: fmt),
                const SizedBox(height: AppSpacing.s16),
                _StatChart(metric: metric, range: range, summary: s, series: data, fmt: fmt),
              ];
            },
            loading: () => const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.s56),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            // The screen replaces the whole page with an error state.
            error: (_, __) => const [SizedBox.shrink()],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero number + trend
// ---------------------------------------------------------------------------

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.metric, required this.range, required this.summary, required this.fmt});

  final StatMetric metric;
  final StatsRange range;
  final MetricSummary summary;
  final StatFormat fmt;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final hero = summary.hero!;
    final overline = fmt.heroOverline(metric, summary.heroKind, range);
    final unit = fmt.unit(metric, value: hero);
    final number = fmt.number(metric, hero);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(overline, style: t.labelLarge!.copyWith(color: p.text2), maxLines: 2),
        const SizedBox(height: AppSpacing.s4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: MetricValue(
            value: number,
            unit: unit,
            size: 64,
            semanticsLabel: '$overline, ${unit == null ? number : '$number $unit'}',
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            if (_trendChip(context) case final chip?) chip,
            if (summary.perWeek != null)
              TintedChip(
                label: fmt.l10n.statPerWeekValue(fmt.f.decimal(summary.perWeek!, 1)),
                // Green with an arrow when the period beat the one before it.
                color: (summary.trend?.delta ?? 0) > 0 ? context.metricColors.improvement : p.text2,
                icon: (summary.trend?.delta ?? 0) > 0 ? Icons.arrow_upward_rounded : null,
              ),
          ],
        ),
      ],
    );
  }

  Widget? _trendChip(BuildContext context) {
    final trend = summary.trend;
    final days = statRangeDays(range);
    if (trend == null || days == null) return null;
    final suffix = fmt.l10n.statTrendVsPrior(days);
    final color = trendColor(context, metric, trend.delta);
    return switch (metric) {
      // Counts and weight move by a few units, not by percent.
      StatMetric.weight => DeltaChip.arrow(value: trend.delta, unit: 'kg', suffix: suffix, color: color),
      StatMetric.workoutCount || StatMetric.cardioSessions =>
        DeltaChip.arrow(value: trend.delta, digits: 0, suffix: suffix, color: color),
      _ => trend.percent == null
          ? null
          : DeltaChip.arrow(value: trend.percent!, digits: 0, unit: '%', suffix: suffix, color: color),
    };
  }
}

class _EmptyRange extends StatelessWidget {
  const _EmptyRange({required this.fmt, required this.range});

  final StatFormat fmt;
  final StatsRange range;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s32),
      child: Center(
        child: Text(
          fmt.l10n.noStatsDataForRangeTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: p.text2),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart
// ---------------------------------------------------------------------------

class _StatChart extends ConsumerWidget {
  const _StatChart({
    required this.metric,
    required this.range,
    required this.summary,
    required this.series,
    required this.fmt,
  });

  final StatMetric metric;
  final StatsRange range;
  final MetricSummary summary;
  final StatSeries series;
  final StatFormat fmt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = fmt.l10n;
    final f = fmt.f;
    final color = statMetricColor(context, metric);
    final points = series.points;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = range.cutoff() ?? firstDay(points) ?? today;

    if (summary.chartKind == StatChartKind.line) {
      final goals = ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults();
      final smoothed = metric == StatMetric.weight || metric == StatMetric.steps;
      // Steps swing day to day, so their average runs over a month; weight
      // keeps the docs/76 seven days.
      final averageDays = metric == StatMetric.steps ? 30 : trendWindowDays;
      return TimeSeriesChart(
        points: points,
        dateLabelBuilder: f.shortDate,
        valueLabelBuilder: (v) => fmt.withUnit(metric, v),
        axisLabelBuilder: (v) => v.abs() >= 1000 ? f.compactAxis(v) : fmt.number(metric, v),
        accentColor: color,
        gradientFill: true,
        yFromZero: metric == StatMetric.steps,
        goalValue: metric == StatMetric.steps ? goals.effectiveDailyStepGoal.toDouble() : null,
        trendValues: smoothed ? movingAverage(points, windowDays: averageDays) : null,
        trendStyle: TrendStyle.dotted,
        showPoints: points.length <= 2,
        highlightLast: true,
        legend: smoothed ? (daily: l10n.weightChartLegendDaily, trend: l10n.statLegendAverageDays(averageDays)) : null,
      );
    }

    // Weekly bars need weeks to group: a single-week range is drawn by day.
    final weekly = summary.chartKind == StatChartKind.weeklyBars && (statRangeDays(range) ?? 99) > 7;
    final drawn = weekly
        ? weeklyBars(metric: metric, points: points, from: from, today: today, fmt: fmt)
        : dailyBars(metric: metric, points: points, from: from, today: today, fmt: fmt);
    final goals = ref.watch(statGoalsProvider);
    final goal = switch (metric) {
      StatMetric.calories => goals.calories,
      StatMetric.protein => goals.protein,
      StatMetric.carbs => goals.carbs,
      StatMetric.fat => goals.fat,
      StatMetric.water => goals.waterLiters,
      _ => null,
    };
    final integer = metric == StatMetric.workoutCount || metric == StatMetric.cardioSessions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LifeyBarChart(
          bars: drawn.bars,
          color: color,
          // The goal is a per-day figure; it means nothing against weekly sums.
          goal: drawn.weekly ? null : goal,
          height: 150,
          barGap: drawn.gap,
          integer: integer,
          semanticsLabel: metric.label(l10n),
        ),
        if (drawn.weekly) ...[
          const SizedBox(height: AppSpacing.s12),
          Text(
            l10n.statWeeklyFootnote,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(color: context.palette.text3),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Range switcher — under the chart; ranges beyond the free history window are
// locked and open the paywall.
// ---------------------------------------------------------------------------

class StatRangeSwitcher extends ConsumerWidget {
  const StatRangeSwitcher({super.key});

  String _label(AppLocalizations l10n, StatsRange r) => switch (r) {
        StatsRange.week => l10n.statRangeWeekLabel,
        StatsRange.month => l10n.statRangeMonthLabel,
        StatsRange.quarter => l10n.statRangeQuarterLabel,
        StatsRange.all => l10n.statRangeAllLabel,
      };

  /// Whether [r] would show data older than the entitlement's history window
  /// (`67` §3.3, `69` §4.1) — a null cutoff is unlimited (Pro, or unresolved and
  /// fail-open, D-P4).
  static bool isLocked(StatsRange r, DateTime? entitlementCutoff) {
    if (entitlementCutoff == null) return false;
    final rangeCutoff = r.cutoff();
    if (rangeCutoff == null) return true; // "all" always exceeds a real cutoff
    return rangeCutoff.isBefore(entitlementCutoff);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final range = ref.watch(statsRangeControllerProvider);
    final cutoff = ref.watch(historyCutoffProvider);
    final locked = {for (final r in StatsRange.values) if (isLocked(r, cutoff)) r};
    return LifeySegmented<StatsRange>(
      segments: [for (final r in StatsRange.values) (r, _label(l10n, r))],
      selected: range,
      locked: locked,
      onChanged: (r) {
        if (locked.contains(r)) {
          openPaywall(context, PaywallTrigger.historyRange);
        } else {
          ref.read(statsRangeControllerProvider.notifier).select(r);
        }
      },
    );
  }
}
