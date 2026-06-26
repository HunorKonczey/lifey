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
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../application/stat_chart_data.dart';
import '../application/stat_metric_controller.dart';
import '../application/stat_summary_data.dart';
import '../application/stats_range_controller.dart';
import '../domain/stat_metric.dart';
import '../domain/stat_summary.dart';

/// Statistics: metric + range popup pickers in a filter strip below the
/// AppBar, KPI summary cards, and a chart. The header collapses on scroll
/// like every other screen in the app.
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final statusTop = MediaQuery.paddingOf(context).top;
    final barTop = statusTop + 8.0;
    // AppBar (58) + filter strip (button ~40 + vertical padding 8×2 = 56)
    final contentTop = barTop + 58.0 + 56.0;

    return Scaffold(
      body: ScrollCollapseListener(
        child: Stack(
          children: [
            Positioned.fill(
              child: _StatisticsBody(topPadding: contentTop),
            ),
            Positioned(
              top: barTop,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: AdaptiveAppBar(title: l10n.statisticsTitle),
                  ),
                  const _StatsFilterStrip(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter strip — metric + range popup buttons side by side
// ---------------------------------------------------------------------------

class _StatsFilterStrip extends StatelessWidget {
  const _StatsFilterStrip();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StatsMetricButton(),
          _StatsRangeButton(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metric picker popup
// ---------------------------------------------------------------------------

class _StatsMetricButton extends ConsumerWidget {
  const _StatsMetricButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final metric = ref.watch(statMetricControllerProvider);
    final availableMetrics = ref.watch(availableStatMetricsProvider);
    final pickableMetrics =
        availableMetrics.isEmpty ? StatMetric.values.toSet() : availableMetrics;

    if (!pickableMetrics.contains(metric)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(statMetricControllerProvider.notifier)
            .select(pickableMetrics.first);
      });
    }

    final collapsed = NavCollapseScope.collapsedOf(context);
    final scheme = Theme.of(context).colorScheme;
    final currentMetric =
        pickableMetrics.contains(metric) ? metric : pickableMetrics.first;

    return PopupMenuButton<StatMetric>(
      initialValue: currentMetric,
      onSelected: (m) =>
          ref.read(statMetricControllerProvider.notifier).select(m),
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        for (final m in StatMetric.values)
          if (pickableMetrics.contains(m))
            PopupMenuItem(
              value: m,
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: m == currentMetric
                        ? Icon(Icons.check, size: 16, color: scheme.primary)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  Text(m.label(l10n)),
                ],
              ),
            ),
      ],
      child: _FilterChip(
        label: currentMetric.label(l10n),
        collapsed: collapsed,
        scheme: scheme,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Range picker popup
// ---------------------------------------------------------------------------

class _StatsRangeButton extends ConsumerWidget {
  const _StatsRangeButton();

  String _label(AppLocalizations l10n, StatsRange range) => switch (range) {
        StatsRange.week => l10n.statRangeWeekLabel,
        StatsRange.month => l10n.statRangeMonthLabel,
        StatsRange.quarter => l10n.statRangeQuarterLabel,
        StatsRange.all => l10n.statRangeAllLabel,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final range = ref.watch(statsRangeControllerProvider);
    final collapsed = NavCollapseScope.collapsedOf(context);
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<StatsRange>(
      initialValue: range,
      onSelected: (r) =>
          ref.read(statsRangeControllerProvider.notifier).select(r),
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        for (final r in StatsRange.values)
          PopupMenuItem(
            value: r,
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: r == range
                      ? Icon(Icons.check, size: 16, color: scheme.primary)
                      : null,
                ),
                const SizedBox(width: 4),
                Text(_label(l10n, r)),
              ],
            ),
          ),
      ],
      child: _FilterChip(
        label: _label(l10n, range),
        collapsed: collapsed,
        scheme: scheme,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared filter chip appearance (label + icon button)
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.collapsed,
    required this.scheme,
  });

  final String label;
  final bool collapsed;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final size = collapsed ? 32.0 : 40.0;
    final radius = collapsed ? 11.0 : 13.0;
    final iconSize = collapsed ? 18.0 : 21.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text(
            label,
            key: ValueKey(label),
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: collapsed ? 11.0 : 13.0,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            child: Icon(
              Icons.filter_list_rounded,
              size: iconSize,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Body — chart only; controls live in the floating header above
// ---------------------------------------------------------------------------

class _StatisticsBody extends ConsumerWidget {
  const _StatisticsBody({required this.topPadding});

  final double topPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final metric = ref.watch(statMetricControllerProvider);
    final chartData = ref.watch(statChartDataProvider);
    final summary = ref.watch(statSummaryProvider);
    final settings =
        ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults();
    final goalValue = metric == StatMetric.steps && settings.dailyStepGoal != null
        ? settings.dailyStepGoal!.toDouble()
        : null;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return chartData.when(
      data: (points) => points.isEmpty
          // EmptyView uses ScrollFill (LayoutBuilder) — needs bounded height
          // from the Positioned.fill ancestor, so return it unwrapped.
          ? EmptyView(icon: Icons.bar_chart, title: l10n.noStatsDataForRangeTitle)
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPad + 24),
              child: _StatisticsChart(
                metric: metric,
                points: points,
                summary: summary.value ?? StatSummary.empty,
                goalValue: goalValue,
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(error: error),
    );
  }
}

class _StatisticsChart extends StatelessWidget {
  const _StatisticsChart({
    required this.metric,
    required this.points,
    required this.summary,
    this.goalValue,
  });

  final StatMetric metric;
  final List<TimeSeriesPoint> points;
  final StatSummary summary;
  final double? goalValue;

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
      StatMetric.steps => mc.steps,
    };
  }

  bool get _isIntegerMetric =>
      metric == StatMetric.workoutCount || metric == StatMetric.steps;

  String _formatValue(double value, AppLocalizations l10n) {
    final formatted = _isIntegerMetric
        ? value.round().toString()
        : value.toStringAsFixed(1);
    final unit = metric.unitLabel(l10n);
    return unit.isEmpty ? formatted : '$formatted $unit';
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
            accentColor: accent,
            areaColor: accent.withValues(alpha: 0.12),
            goalValue: goalValue,
          ),
        ),
      ],
    );
  }
}
