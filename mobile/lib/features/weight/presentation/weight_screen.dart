import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/entitlements/entitlement_providers.dart';
import '../../../core/entitlements/history_cutoff.dart';
import '../../../core/format/lifey_format.dart';
import '../../../core/health/health_controller.dart';
import '../../../core/health/health_service.dart';
import '../../../core/health/weight_health_backfill_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/charts/time_series_chart.dart';
import '../../../shared/widgets/ds/delta_chip.dart';
import '../../../shared/widgets/ds/grouped_list_item.dart';
import '../../../shared/widgets/ds/lifey_card.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/ds/lifey_segmented.dart';
import '../../../shared/widgets/ds/metric_value.dart';
import '../../../shared/widgets/ds/section_label.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/history_boundary_row.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../../../shared/widgets/shell_fab.dart';
import '../application/weight_chart_data.dart';
import '../application/weight_controller.dart';
import '../application/weight_headline.dart';
import '../application/weight_range.dart';
import '../application/weight_trend_data.dart';
import '../domain/weight_entry.dart';
import 'widgets/add_weight_sheet.dart';
import 'widgets/weight_goal_band.dart';
import 'widgets/weight_hero_header.dart';

/// Weight (canvas Lifey 4 › 4.1; docs/redesign/77-mobile-redesign-plan.md R4):
/// one hero card — the current weight at 64 px with its two changes, the goal
/// band, the range switcher and the chart with its 7-day average — over a
/// "History" list of signed changes. The large title collapses as the page
/// scrolls; "+ Log" is the shell's floating action.
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

  void _openAddSheet() => showAddWeightSheet(context);

  void _pushFab() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ref.read(shellFabProvider.notifier).set((
      tabIndex: 3,
      icon: Icons.add,
      label: l10n.logFabLabel,
      onPressed: _openAddSheet,
      extended: true,
      onLongPress: null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(weightControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    // The pinned header collapses to the status bar + a 52 px row; the
    // pull-to-refresh spinner starts below it.
    final headerBottom = MediaQuery.paddingOf(context).top + 52;

    ref.listen(activeShellTabProvider, (_, next) {
      if (next == 3) _pushFab();
    });

    return Scaffold(
      body: ScrollCollapseListener(
        child: RefreshIndicator(
          edgeOffset: headerBottom,
          onRefresh: () => ref.read(weightControllerProvider.notifier).refresh(),
          child: state.when(
            data: (entries) => _WeightBody(entries: entries),
            loading: () => CustomScrollView(slivers: [
              LifeyHeader(title: l10n.weightTitle),
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            ]),
            error: (error, _) => CustomScrollView(slivers: [
              LifeyHeader(title: l10n.weightTitle),
              SliverFillRemaining(
                child: ErrorView(
                  error: error,
                  onRetry: () => ref.read(weightControllerProvider.notifier).refresh(),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _WeightBody extends ConsumerWidget {
  const _WeightBody({required this.entries});

  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.paddingOf(context).bottom + AppSpacing.s56 + AppSpacing.s32;
    final headline = ref.watch(weightHeadlineProvider);

    final header = LifeyHeader(
      title: l10n.weightTitle,
      actions: const [_WeightMenu()],
    );

    if (entries.isEmpty || headline == null) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          header,
          // EmptyView is a scroll-fill of its own: it needs the sliver's bounded
          // height, not intrinsics.
          SliverFillRemaining(
            child: EmptyView(
              icon: Icons.monitor_weight_outlined,
              title: l10n.noWeightEntriesYetTitle,
              subtitle: l10n.tapPlusToAddFirstOneMessage,
              action: const _ImportFromHealthButton(),
            ),
          ),
        ],
      );
    }

    final range = ref.watch(weightRangeControllerProvider);
    // Intersected with the free history window (`67` §3.2, D-P6), same as
    // [weightChartDataProvider] — this list re-filters `entries`
    // independently rather than reading that provider, so it needs the same
    // combination applied here too. `truncated` compares against the
    // *range-only* result, not raw `entries` — otherwise a Pro user who
    // simply picked "week" would also see the boundary row, which isn't the
    // gate firing at all.
    final rangeCutoff = range.cutoff();
    final withinRange = rangeCutoff == null
        ? entries
        : entries.where((e) => !e.date.toLocal().isBefore(rangeCutoff)).toList();
    final cutoff = combineHistoryCutoffs(rangeCutoff, ref.watch(historyCutoffProvider));
    final filtered =
        cutoff == null ? entries : entries.where((e) => !e.date.toLocal().isBefore(cutoff)).toList();
    final truncated = filtered.length < withinRange.length;

    const gutter = EdgeInsets.symmetric(horizontal: AppSpacing.screen);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        header,
        SliverPadding(
          padding: gutter.copyWith(top: AppSpacing.s16),
          sliver: SliverToBoxAdapter(child: _HeroCard(headline: headline)),
        ),
        SliverPadding(
          padding: gutter.copyWith(top: AppSpacing.s24, bottom: AppSpacing.s8),
          sliver: SliverToBoxAdapter(child: SectionLabel(l10n.weightHistoryLabel)),
        ),
        SliverPadding(
          padding: gutter,
          sliver: SliverList.builder(
            itemCount: filtered.length,
            itemBuilder: (context, i) => GroupedListItem(
              first: i == 0,
              last: i == filtered.length - 1,
              dividerInset: AppSpacing.s16,
              child: _HistoryRow(
                entry: filtered[i],
                delta: i + 1 < filtered.length ? filtered[i].weight - filtered[i + 1].weight : null,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: gutter.copyWith(top: AppSpacing.s12, bottom: bottomPad),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (truncated) const HistoryBoundaryRow(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero card: hero number + goal band + range + chart
// ---------------------------------------------------------------------------

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.headline});

  final WeightHeadline headline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final mc = context.metricColors;
    final range = ref.watch(weightRangeControllerProvider);
    final chartData = ref.watch(weightChartDataProvider);
    final trend = ref.watch(weightTrendProvider).value;

    String rangeLabel(WeightRange r) => switch (r) {
          WeightRange.week => l10n.weightRangeWeekLabel,
          WeightRange.month => l10n.weightRangeMonthLabel,
          WeightRange.quarter => l10n.weightRangeQuarterLabel,
          WeightRange.all => l10n.weightRangeAllLabel,
        };

    return LifeyCard.hero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WeightHeroHeader(headline: headline),
          const SizedBox(height: AppSpacing.s16),
          WeightGoalBand(headline: headline),
          const SizedBox(height: AppSpacing.s16),
          LifeySegmented<WeightRange>(
            segments: [for (final r in WeightRange.values) (r, rangeLabel(r))],
            selected: range,
            onChanged: (r) => ref.read(weightRangeControllerProvider.notifier).select(r),
          ),
          const SizedBox(height: AppSpacing.s16),
          chartData.when(
            data: (points) => points.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
                    child: Center(
                      child: Text(
                        l10n.noWeightDataForRangeTitle,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: p.text2),
                      ),
                    ),
                  )
                : TimeSeriesChart(
                    points: points,
                    dateLabelBuilder: (d) => f.shortDate(d),
                    valueLabelBuilder: (value) => l10n.weightKgValue(f.decimal(value, 1)),
                    axisLabelBuilder: (value) => f.decimal(value, 1),
                    accentColor: mc.weight,
                    gradientFill: true,
                    // The canvas draws the daily line as the hero and the
                    // 7-day average dotted over it (decision D-R4.1; the
                    // docs/76 D-W3 style stays available as `emphasized`).
                    trendValues: trend,
                    trendStyle: TrendStyle.dotted,
                    showPoints: false,
                    highlightLast: true,
                    legend: (daily: l10n.weightChartLegendDaily, trend: l10n.weightTrendCaption),
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => ErrorView(error: error),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History row — the weight, when, and the signed change from the one before
// ---------------------------------------------------------------------------

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.delta});

  final WeightEntry entry;

  /// Change vs the previous (older) entry; null for the oldest.
  final double? delta;

  String _relativeDate(BuildContext context, AppLocalizations l10n) {
    final f = LifeyFormat.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = entry.date.toLocal();
    final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return l10n.weightHistoryTodayLabel;
    if (diff == 1) return l10n.weightHistoryYesterdayLabel;
    return '${f.weekdayShort(d)}, ${f.shortDate(d)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MetricValue(value: f.decimal(entry.weight, 1), unit: 'kg', size: 19),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  _relativeDate(context, l10n),
                  style: t.bodyMedium!.copyWith(fontWeight: FontWeight.w500, color: p.text2),
                ),
              ],
            ),
          ),
          if (delta != null) DeltaChip.signed(value: delta!),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ⋮ menu and the Health import
// ---------------------------------------------------------------------------

/// The header's ⋮ (canvas: a round 44 px button): "Import from Health" when
/// Apple Health / Health Connect is connected — the only thing the menu
/// holds today, so without it the button is not drawn at all.
class _WeightMenu extends ConsumerWidget {
  const _WeightMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(healthServiceProvider).isAvailable;
    final connected = ref.watch(healthControllerProvider).value ?? false;
    if (!available || !connected) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    return PopupMenuButton<void>(
      tooltip: l10n.weightMoreTooltip,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        PopupMenuItem<void>(
          onTap: () => importWeightFromHealth(context, ref),
          child: Text(l10n.importFromHealthButton),
        ),
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: p.nested, shape: BoxShape.circle),
        child: Icon(Icons.more_vert_rounded, size: 22, color: p.text),
      ),
    );
  }
}

/// Backfills the last 30 days of body-mass samples from Health (one entry per
/// day, skipping days already logged) and says how many came in.
Future<void> importWeightFromHealth(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final count = await ref.read(weightHealthBackfillServiceProvider).backfill();
    if (!context.mounted) return;
    if (count > 0) {
      AppSnackbar.showSuccess(context, title: l10n.weightImportedFromHealth(count));
    } else {
      AppSnackbar.showInfo(context, title: l10n.noNewWeightFromHealth);
    }
  } catch (_) {
    if (!context.mounted) return;
    AppSnackbar.showError(context, title: l10n.noNewWeightFromHealth);
  }
}

/// Manual "Import from Health" action of the empty state. Only rendered once
/// the user has connected Health (Apple Health on iOS, Health Connect on
/// Android); otherwise it collapses to nothing.
class _ImportFromHealthButton extends ConsumerStatefulWidget {
  const _ImportFromHealthButton();

  @override
  ConsumerState<_ImportFromHealthButton> createState() => _ImportFromHealthButtonState();
}

class _ImportFromHealthButtonState extends ConsumerState<_ImportFromHealthButton> {
  bool _importing = false;

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    await importWeightFromHealth(context, ref);
    if (mounted) setState(() => _importing = false);
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(healthServiceProvider).isAvailable;
    final connected = ref.watch(healthControllerProvider).value ?? false;
    if (!available || !connected) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return FilledButton.tonalIcon(
      onPressed: _importing ? null : _import,
      icon: _importing
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.favorite_rounded, size: 20),
      label: Text(l10n.importFromHealthButton),
    );
  }
}
