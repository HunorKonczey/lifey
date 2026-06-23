import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/charts/time_series_chart.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/weight_chart_data.dart';
import '../application/weight_controller.dart';
import '../application/weight_range.dart';
import '../domain/weight_entry.dart';
import 'widgets/add_weight_sheet.dart';

/// Weight: latest reading, a range selector, and a chart of daily weights.
/// Adding stays in the FAB sheet; there's no entry list here anymore — see
/// docs/.. (none yet) for the planned per-day detail view.
class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});

  Future<void> _openAddSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddWeightSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weightControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.weightTitle), centerTitle: false),
      floatingActionButton: FloatingActionButton(
        // See nutrition_screen.dart: shell tabs stay mounted simultaneously
        // (IndexedStack), so each FAB needs a non-default hero tag.
        heroTag: null,
        onPressed: () => _openAddSheet(context),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(weightControllerProvider.notifier).refresh(),
        child: state.when(
          data: (entries) => entries.isEmpty
              ? EmptyView(
                  icon: Icons.monitor_weight_outlined,
                  title: l10n.noWeightEntriesYetTitle,
                  subtitle: l10n.tapPlusToAddFirstOneMessage,
                )
              : _WeightStats(latest: entries.first),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.read(weightControllerProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}

class _WeightStats extends ConsumerWidget {
  const _WeightStats({required this.latest});

  final WeightEntry latest;

  static final _chartDateLabel = DateFormat('MMM d');

  String _formatDelta(double delta) {
    final sign = delta > 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final range = ref.watch(weightRangeControllerProvider);
    final chartData = ref.watch(weightChartDataProvider);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            l10n.latestEntryLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.weightKgValue(latest.weight.toStringAsFixed(1)),
            style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          SegmentedButton<WeightRange>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: WeightRange.week, label: Text(l10n.weightRangeWeekLabel)),
              ButtonSegment(value: WeightRange.month, label: Text(l10n.weightRangeMonthLabel)),
              ButtonSegment(value: WeightRange.quarter, label: Text(l10n.weightRangeQuarterLabel)),
              ButtonSegment(value: WeightRange.all, label: Text(l10n.weightRangeAllLabel)),
            ],
            selected: {range},
            onSelectionChanged: (selection) =>
                ref.read(weightRangeControllerProvider.notifier).select(selection.first),
          ),
          const SizedBox(height: 24),
          chartData.when(
            data: (points) => points.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      l10n.noWeightDataForRangeTitle,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : TimeSeriesChart(
                    points: points,
                    dateLabelBuilder: _chartDateLabel.format,
                    deltaLabelBuilder: (delta) => l10n.weightKgValue(_formatDelta(delta)),
                    showDeltaLabels: true,
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => ErrorView(error: error),
          ),
        ],
      ),
    );
  }
}
