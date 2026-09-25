import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ads/banner_ad_slot.dart';
import '../../../core/ads/nav_reserved_space.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/ds/lifey_segmented.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../application/stat_chart_data.dart';
import '../application/stat_kind_filter_controller.dart';
import '../application/stat_metric_controller.dart';
import '../domain/stat_kind_filter.dart';
import '../domain/stat_metric.dart';
import 'widgets/stat_hero_card.dart';
import 'widgets/stat_metric_chips.dart';
import 'widgets/stat_side_stats.dart';

/// Statistics (canvas Lifey 4 › 5; docs/redesign/77-mobile-redesign-plan.md
/// R4.5–R4.7): metric chips, then one hero card — the metric's number over the
/// range with its trend, the chart that fits it, the range switcher — and three
/// side figures that mean something for that metric. The large title collapses
/// as the page scrolls.
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  /// Only these metrics are affected by the strength / cardio switch (D-C3.4);
  /// for the rest it would be a control that does nothing.
  static bool _hasKindFilter(StatMetric m) =>
      m == StatMetric.workoutCount || m == StatMetric.workoutMinutes || m == StatMetric.activeCalories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final metric = ref.watch(statMetricControllerProvider);
    final summary = ref.watch(statSummaryProvider).value;
    final failure = ref.watch(statCurrentSeriesProvider).error;
    final bannerHeight = ref.watch(bannerAdSlotHeightProvider(4));
    final bottomPad = MediaQuery.paddingOf(context).bottom + bannerHeight + AppSpacing.s32;
    const gutter = EdgeInsets.symmetric(horizontal: AppSpacing.screen);

    return Scaffold(
      body: ScrollCollapseListener(
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  LifeyHeader(title: l10n.statisticsTitle),
                  // A stream that failed replaces the page: the chips and the
                  // range switcher would only lead to the same error.
                  if (failure != null)
                    SliverFillRemaining(child: ErrorView(error: failure))
                  else ...[
                  if (_hasKindFilter(metric))
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, 0),
                      sliver: SliverToBoxAdapter(child: _KindFilter()),
                    ),
                  const SliverPadding(
                    padding: EdgeInsets.only(top: AppSpacing.s12),
                    sliver: SliverToBoxAdapter(child: StatMetricChips()),
                  ),
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s16, AppSpacing.screen, 0),
                    sliver: SliverToBoxAdapter(child: StatHeroCard()),
                  ),
                  if (summary != null && summary.sides.isNotEmpty)
                    SliverPadding(
                      padding: gutter.copyWith(top: AppSpacing.s12),
                      sliver: SliverToBoxAdapter(child: StatSideStats(metric: metric, sides: summary.sides)),
                    ),
                  SliverPadding(
                    padding: gutter.copyWith(top: AppSpacing.s12),
                    sliver: const SliverToBoxAdapter(child: StatRangeSwitcher()),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bannerBottom(MediaQuery.paddingOf(context).bottom),
              child: const BannerAdSlot(tabIndex: 4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything / strength / cardio (docs/cardio/56-cardio-statistics-plan.md
/// D-C3.4) — a real three-way switch, so someone stuck on an empty "no cardio
/// this range" chart can tap straight back.
class _KindFilter extends ConsumerWidget {
  const _KindFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(statKindFilterControllerProvider);
    String label(StatKindFilter f) => switch (f) {
          StatKindFilter.all => l10n.allFilterLabel,
          StatKindFilter.strength => l10n.activityTypeStrength,
          StatKindFilter.cardio => l10n.sessionKindCardioLabel,
        };
    return Semantics(
      container: true,
      label: l10n.statKindFilterSemantics,
      child: LifeySegmented<StatKindFilter>(
        segments: [for (final f in StatKindFilter.values) (f, label(f))],
        selected: selected,
        onChanged: (f) => ref.read(statKindFilterControllerProvider.notifier).select(f),
      ),
    );
  }
}
