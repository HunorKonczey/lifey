import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/charts/stats_range.dart';
import '../../../shared/widgets/charts/time_series_chart.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../../dashboard/presentation/widgets/stat_card.dart';
import '../application/stat_chart_data.dart';
import '../application/stat_metric_controller.dart';
import '../application/stat_summary_data.dart';
import '../application/stats_range_controller.dart';
import '../domain/stat_metric.dart';
import '../domain/stat_summary.dart';

/// Statistics: a metric picker, a range selector, KPI summary cards, and a
/// chart of the selected metric's daily values — mirroring the weight
/// screen's layout, generalized to any [StatMetric].
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final statusTop = MediaQuery.paddingOf(context).top;
    final barTop = statusTop + 8.0;
    final contentTop = barTop + 58.0 + 12.0;

    return Scaffold(
      body: ScrollCollapseListener(
        child: Stack(
          children: [
            Positioned.fill(
              child: _StatisticsBody(topPadding: contentTop),
            ),
            Positioned(
              top: barTop,
              left: 12,
              right: 12,
              child: AdaptiveAppBar(title: l10n.statisticsTitle),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticsBody extends ConsumerWidget {
  const _StatisticsBody({required this.topPadding});

  final double topPadding;

  String _rangeLabel(AppLocalizations l10n, StatsRange range) => switch (range) {
        StatsRange.week => l10n.statRangeWeekLabel,
        StatsRange.month => l10n.statRangeMonthLabel,
        StatsRange.quarter => l10n.statRangeQuarterLabel,
        StatsRange.all => l10n.statRangeAllLabel,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final metric = ref.watch(statMetricControllerProvider);
    final range = ref.watch(statsRangeControllerProvider);
    final chartData = ref.watch(statChartDataProvider);
    final summary = ref.watch(statSummaryProvider);

    // Metrics with no data at all (e.g. activeCalories with no Apple Health
    // workouts ever paired) are hidden from the picker — selecting one would
    // always land on the empty state. Falls back to the full list for a
    // brand-new user with no data anywhere yet, so the picker isn't empty.
    final availableMetrics = ref.watch(availableStatMetricsProvider);
    final pickableMetrics = availableMetrics.isEmpty ? StatMetric.values.toSet() : availableMetrics;
    // A Set has identity equality, so a plain ValueKey(pickableMetrics) would
    // never match across rebuilds — derive a content-stable string instead.
    final pickableMetricsKey = (pickableMetrics.map((m) => m.name).toList()..sort()).join(',');
    if (!pickableMetrics.contains(metric)) {
      // Deferred: switching the selection here directly would mutate
      // provider state mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(statMetricControllerProvider.notifier).select(pickableMetrics.first);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // topPadding clears the floating AdaptiveAppBar; the existing 24px
          // below becomes the gap between bar and the metric picker.
          padding: EdgeInsets.fromLTRB(16, topPadding, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownMenu<StatMetric>(
                key: ValueKey(pickableMetricsKey),
                expandedInsets: EdgeInsets.zero,
                initialSelection: pickableMetrics.contains(metric) ? metric : pickableMetrics.first,
                dropdownMenuEntries: [
                  for (final m in StatMetric.values)
                    if (pickableMetrics.contains(m))
                      DropdownMenuEntry(value: m, label: m.label(l10n)),
                ],
                onSelected: (selected) {
                  if (selected != null) {
                    ref.read(statMetricControllerProvider.notifier).select(selected);
                  }
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: SegmentedButton<StatsRange>(
                  showSelectedIcon: false,
                  segments: [
                    for (final r in StatsRange.values)
                      ButtonSegment(value: r, label: Text(_rangeLabel(l10n, r))),
                  ],
                  selected: {range},
                  onSelectionChanged: (selection) =>
                      ref.read(statsRangeControllerProvider.notifier).select(selection.first),
                ),
              ),
            ],
          ),
        ),
        // EmptyView/ErrorView are each already scrollable (ScrollFill) and
        // need bounded height to fill — Expanded gives them that, instead of
        // nesting them in another unbounded SingleChildScrollView.
        Expanded(
          child: chartData.when(
            data: (points) => points.isEmpty
                ? EmptyView(
                    icon: Icons.bar_chart,
                    title: l10n.noStatsDataForRangeTitle,
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      24,
                      16,
                      MediaQuery.paddingOf(context).bottom + 24,
                    ),
                    child: _StatisticsChart(
                      metric: metric,
                      points: points,
                      summary: summary.value ?? StatSummary.empty,
                    ),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorView(error: error),
          ),
        ),
      ],
    );
  }
}

class _StatisticsChart extends StatelessWidget {
  const _StatisticsChart({
    required this.metric,
    required this.points,
    required this.summary,
  });

  final StatMetric metric;
  final List<TimeSeriesPoint> points;
  final StatSummary summary;

  static final _chartDateLabel = DateFormat('MMM d');

  Color _metricColor(BuildContext context, StatMetric m) {
    final mc = context.metricColors;
    final scheme = Theme.of(context).colorScheme;
    return switch (m) {
      StatMetric.calories => mc.calories,
      StatMetric.protein => mc.protein,
      StatMetric.carbs => mc.carbs,
      StatMetric.fat => mc.fat,
      StatMetric.water => mc.water,
      StatMetric.weight => mc.weight,
      StatMetric.activeCalories => mc.calories,
      StatMetric.workoutMinutes => scheme.primary,
      StatMetric.workoutCount => scheme.primary,
    };
  }

  String _formatValue(double value, AppLocalizations l10n) {
    final formatted = metric == StatMetric.workoutCount
        ? value.round().toString()
        : value.toStringAsFixed(1);
    final unit = metric.unitLabel(l10n);
    return unit.isEmpty ? formatted : '$formatted $unit';
  }

  String _formatDelta(double delta, AppLocalizations l10n) {
    final sign = delta > 0 ? '+' : '';
    return '$sign${_formatValue(delta, l10n)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final trendPercent = summary.trendPercent;
    final accent = _metricColor(context, metric);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: l10n.statSumLabel,
                value: _formatValue(summary.sum, l10n),
                icon: Icons.functions,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: l10n.statAverageLabel,
                value: _formatValue(summary.average, l10n),
                icon: Icons.show_chart,
                color: accent,
                trailing: trendPercent == null
                    ? null
                    : Icon(
                        trendPercent >= 0
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: l10n.statMinLabel,
                value: _formatValue(summary.min, l10n),
                icon: Icons.south,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: l10n.statMaxLabel,
                value: _formatValue(summary.max, l10n),
                icon: Icons.north,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          padding: const EdgeInsets.all(16),
          child: TimeSeriesChart(
            points: points,
            dateLabelBuilder: _chartDateLabel.format,
            valueLabelBuilder: (value) => _formatValue(value, l10n),
            deltaLabelBuilder: (delta) => _formatDelta(delta, l10n),
            showDeltaLabels: true,
          ),
        ),
      ],
    );
  }
}
