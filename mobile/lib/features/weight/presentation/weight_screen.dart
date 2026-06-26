import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/health/health_controller.dart';
import '../../../core/health/health_service.dart';
import '../../../core/health/weight_health_backfill_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/app_snackbar.dart';
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

/// Weight: a chart card (current reading + range + TimeSeriesChart) over a
/// History list of past entries, mirroring the redesign mockup
/// (docs/design · screen 04).
class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  @override
  void initState() {
    super.initState();
    // Push the FAB once on first build — the activeShellTabProvider listener
    // only fires on a *change* to tab 3, so it misses the case where Weight is
    // the tab already shown at launch.
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushFab());
  }

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
                          action: const _ImportFromHealthButton(),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mc = context.metricColors;
    final l10n = AppLocalizations.of(context)!;
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
          // ── Chart card: current reading + range + chart ────────────────
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current reading + delta
                Text(
                  l10n.weightCurrentLabel,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      latest.weight.toStringAsFixed(1),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        letterSpacing: -1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'kg',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (delta != null) ...[
                      const SizedBox(width: 10),
                      _DeltaLabel(delta: delta, large: true),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // Range selector — pill segmented, inside the card
                _RangePills(
                  selected: range,
                  onSelect: (r) => ref
                      .read(weightRangeControllerProvider.notifier)
                      .select(r),
                ),
                const SizedBox(height: 16),

                // Chart
                chartData.when(
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
                          accentColor: mc.weight,
                          areaColor: mc.weight.withValues(alpha: 0.12),
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => ErrorView(error: error),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── History ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              l10n.weightHistoryLabel.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          Builder(builder: (context) {
            final cutoff = range.cutoff();
            final filtered = cutoff == null
                ? entries
                : entries
                    .where((e) => !e.date.toLocal().isBefore(cutoff))
                    .toList();
            return Column(
              children: [
                for (var i = 0; i < filtered.length; i++) ...[
                  _HistoryRow(
                    entry: filtered[i],
                    delta: i + 1 < filtered.length
                        ? filtered[i].weight - filtered[i + 1].weight
                        : null,
                  ),
                  if (i < filtered.length - 1) const SizedBox(height: 8),
                ],
              ],
            );
          }),

          // ── Apple Health import ────────────────────────────────────────
          const SizedBox(height: 16),
          const _ImportFromHealthButton(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Range selector — pill segmented control (matches design screen 04)
// ---------------------------------------------------------------------------

class _RangePills extends StatelessWidget {
  const _RangePills({required this.selected, required this.onSelect});

  final WeightRange selected;
  final ValueChanged<WeightRange> onSelect;

  String _label(AppLocalizations l10n, WeightRange r) => switch (r) {
        WeightRange.week => l10n.weightRangeWeekLabel,
        WeightRange.month => l10n.weightRangeMonthLabel,
        WeightRange.quarter => l10n.weightRangeQuarterLabel,
        WeightRange.all => l10n.weightRangeAllLabel,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        children: [
          for (final r in WeightRange.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(r),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: AppDuration.fast,
                  curve: AppCurve.standard,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: r == selected ? scheme.primary : Colors.transparent,
                    borderRadius: AppRadius.pill,
                  ),
                  child: Text(
                    _label(l10n, r),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: r == selected
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                      fontWeight:
                          r == selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History row — one past weight entry with relative date + delta
// ---------------------------------------------------------------------------

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.delta});

  final WeightEntry entry;

  /// Change vs the previous (older) entry. Negative = weight loss.
  final double? delta;

  static final _fallbackDate = DateFormat('EEE, MMM d');

  String _relativeDate(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = entry.date.toLocal();
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return l10n.weightHistoryTodayLabel;
    if (diff == 1) return l10n.weightHistoryYesterdayLabel;
    return _fallbackDate.format(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.weight.toStringAsFixed(1)} kg',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _relativeDate(context),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (delta != null && delta != 0) _DeltaLabel(delta: delta!),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Delta label — arrow + change, green when down (loss), brown when up
// ---------------------------------------------------------------------------

class _DeltaLabel extends StatelessWidget {
  const _DeltaLabel({required this.delta, this.large = false});

  final double delta;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final mc = context.metricColors;
    // Weight loss (down) is the positive outcome.
    final down = delta < 0;
    final color = down ? mc.positive : mc.negative;
    final magnitude = delta.abs().toStringAsFixed(1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          down ? Icons.arrow_downward : Icons.arrow_upward,
          size: large ? 18 : 16,
          color: color,
        ),
        Text(
          large ? '$magnitude kg' : magnitude,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: large ? 15 : 12,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Apple Health import button
// ---------------------------------------------------------------------------

/// Manual "Import from Apple Health" action: backfills the last 30 days of
/// body-mass samples (one entry per day, skipping days already logged). Only
/// rendered on iOS once the user has connected Apple Health; otherwise it
/// collapses to nothing.
class _ImportFromHealthButton extends ConsumerStatefulWidget {
  const _ImportFromHealthButton();

  @override
  ConsumerState<_ImportFromHealthButton> createState() =>
      _ImportFromHealthButtonState();
}

class _ImportFromHealthButtonState
    extends ConsumerState<_ImportFromHealthButton> {
  bool _importing = false;

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final count =
          await ref.read(weightHealthBackfillServiceProvider).backfill();
      if (!mounted) return;
      if (count > 0) {
        AppSnackbar.showSuccess(context, title: l10n.weightImportedFromHealth(count));
      } else {
        AppSnackbar.showInfo(context, title: l10n.noNewWeightFromHealth);
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.showError(context, title: l10n.noNewWeightFromHealth);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(healthServiceProvider).isAvailable;
    final connected = ref.watch(appleHealthControllerProvider).value ?? false;
    if (!available || !connected) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return FilledButton.tonalIcon(
      onPressed: _importing ? null : _import,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
      ),
      icon: _importing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.apple, size: 20),
      label: Text(l10n.importFromAppleHealthButton),
    );
  }
}
