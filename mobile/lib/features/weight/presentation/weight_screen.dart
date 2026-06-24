import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/charts/time_series_chart.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../../../shared/widgets/shell_fab.dart';
import '../application/weight_chart_data.dart';
import '../application/weight_controller.dart';
import '../application/weight_range.dart';
import '../domain/weight_entry.dart';
import 'widgets/add_weight_sheet.dart';

/// Weight: latest reading hero card, range selector, and chart.
class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  void _openAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddWeightSheet(),
    );
  }

  void _pushFab() {
    if (!mounted) return;
    ref.read(shellFabProvider.notifier).set((
      tabIndex: 3,
      icon: Icons.add,
      label: '',
      onPressed: _openAddSheet,
      extended: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(weightControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    final statusTop = MediaQuery.paddingOf(context).top;
    final barTop = statusTop + 8.0;
    final contentTop = barTop + 58.0 + 12.0;

    ref.listen(activeShellTabProvider, (_, next) {
      if (next == 3) _pushFab();
    });

    return Scaffold(
      body: ScrollCollapseListener(
        child: Stack(
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                displacement: contentTop,
                onRefresh: () =>
                    ref.read(weightControllerProvider.notifier).refresh(),
                child: state.when(
                  data: (entries) => entries.isEmpty
                      ? EmptyView(
                          icon: Icons.monitor_weight_outlined,
                          title: l10n.noWeightEntriesYetTitle,
                          subtitle: l10n.tapPlusToAddFirstOneMessage,
                        )
                      : _WeightBody(
                          entries: entries,
                          contentTop: contentTop,
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => ErrorView(
                    error: error,
                    onRetry: () =>
                        ref.read(weightControllerProvider.notifier).refresh(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: barTop,
              left: 12,
              right: 12,
              child: AdaptiveAppBar(title: l10n.weightTitle),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — scrollable content
// ---------------------------------------------------------------------------

class _WeightBody extends ConsumerWidget {
  const _WeightBody({required this.entries, required this.contentTop});

  final List<WeightEntry> entries;
  final double contentTop;

  static final _chartDateLabel = DateFormat('MMM d');
  static final _entryDateLabel = DateFormat('EEE, MMM d');

  String _formatDelta(double delta) {
    final sign = delta > 0 ? '+' : '';
    return '$sign${delta.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final weightColor = context.metricColors.weight;
    final range = ref.watch(weightRangeControllerProvider);
    final chartData = ref.watch(weightChartDataProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom + 24;

    final latest = entries.first;
    final previous = entries.length > 1 ? entries[1] : null;
    final delta = previous != null ? latest.weight - previous.weight : null;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, contentTop, 16, bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero card ──────────────────────────────────────────────────
          _WeightHeroCard(
            latest: latest,
            delta: delta,
            weightColor: weightColor,
            scheme: scheme,
            theme: theme,
            l10n: l10n,
            dateLabel: _entryDateLabel,
          ),
          const SizedBox(height: 16),

          // ── Range selector ─────────────────────────────────────────────
          SegmentedButton<WeightRange>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: WeightRange.week,
                  label: Text(l10n.weightRangeWeekLabel)),
              ButtonSegment(
                  value: WeightRange.month,
                  label: Text(l10n.weightRangeMonthLabel)),
              ButtonSegment(
                  value: WeightRange.quarter,
                  label: Text(l10n.weightRangeQuarterLabel)),
              ButtonSegment(
                  value: WeightRange.all,
                  label: Text(l10n.weightRangeAllLabel)),
            ],
            selected: {range},
            onSelectionChanged: (selection) => ref
                .read(weightRangeControllerProvider.notifier)
                .select(selection.first),
          ),
          const SizedBox(height: 16),

          // ── Chart card ────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            padding: const EdgeInsets.all(16),
            child: chartData.when(
              data: (points) => points.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          l10n.noWeightDataForRangeTitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : TimeSeriesChart(
                      points: points,
                      dateLabelBuilder: _chartDateLabel.format,
                      valueLabelBuilder: (value) =>
                          l10n.weightKgValue(value.toStringAsFixed(1)),
                      deltaLabelBuilder: (delta) =>
                          l10n.weightKgValue(_formatDelta(delta)),
                      showDeltaLabels: true,
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => ErrorView(error: error),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero card
// ---------------------------------------------------------------------------

class _WeightHeroCard extends StatelessWidget {
  const _WeightHeroCard({
    required this.latest,
    required this.delta,
    required this.weightColor,
    required this.scheme,
    required this.theme,
    required this.l10n,
    required this.dateLabel,
  });

  final WeightEntry latest;
  final double? delta;
  final Color weightColor;
  final ColorScheme scheme;
  final ThemeData theme;
  final AppLocalizations l10n;
  final DateFormat dateLabel;

  @override
  Widget build(BuildContext context) {
    final deltaPositive = delta != null && delta! > 0;
    final deltaColor = delta == null
        ? scheme.onSurfaceVariant
        : deltaPositive
            ? context.metricColors.negative
            : context.metricColors.positive;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: weightColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Icon(Icons.monitor_weight,
                      size: 20, color: weightColor),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.latestEntryLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                dateLabel.format(latest.date.toLocal()),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                latest.weight.toStringAsFixed(1),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: weightColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'kg',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (delta != null) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: deltaColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${deltaPositive ? '+' : ''}${delta!.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: deltaColor,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
