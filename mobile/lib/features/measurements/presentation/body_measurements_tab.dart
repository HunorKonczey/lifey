import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/lifey_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/charts/time_series_chart.dart';
import '../../../shared/widgets/ds/delta_chip.dart';
import '../../../shared/widgets/ds/grouped_list_item.dart';
import '../../../shared/widgets/ds/lifey_card.dart';
import '../../../shared/widgets/ds/metric_value.dart';
import '../../../shared/widgets/ds/section_label.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/body_measurement_controller.dart';
import '../application/body_measurement_providers.dart';
import '../domain/body_measurement.dart';
import 'widgets/add_measurement_sheet.dart';
import 'widgets/measurement_site_chips.dart';

/// The measurements tab of the Body screen (docs/80 §7 P3): a site picker, the
/// selected site's latest value with its change and a line chart, and its
/// history as swipe-to-delete rows. No Scaffold of its own — the Body screen
/// owns the app bar and the floating "Log" button ([logMeasurement]).
class BodyMeasurementsTab extends ConsumerWidget {
  const BodyMeasurementsTab({super.key});

  /// Opens the add sheet on the site currently shown.
  static void logMeasurement(BuildContext context, WidgetRef ref) =>
      showAddMeasurementSheet(context, initialSite: ref.read(selectedMeasurementSiteProvider));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(bodyMeasurementControllerProvider);
    final site = ref.watch(selectedMeasurementSiteProvider);
    final bottomPad = MediaQuery.paddingOf(context).bottom + AppSpacing.s56 + AppSpacing.s32;

    return RefreshIndicator(
      onRefresh: () => ref.read(bodyMeasurementControllerProvider.notifier).refresh(),
      child: state.when(
        data: (all) => all.isEmpty
            ? CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    child: EmptyView(
                      icon: Icons.straighten_rounded,
                      title: l10n.bodyMeasurementsEmptyTitle,
                      subtitle: l10n.bodyMeasurementsEmptySubtitle,
                    ),
                  ),
                ],
              )
            : _Body(all: all, site: site, bottomPad: bottomPad),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.read(bodyMeasurementControllerProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.all, required this.site, required this.bottomPad});

  final List<BodyMeasurement> all;
  final MeasurementSite site;
  final double bottomPad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final forSite = all.where((m) => m.site == site).toList();
    const gutter = EdgeInsets.symmetric(horizontal: AppSpacing.screen);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: gutter.copyWith(top: AppSpacing.s8),
          sliver: SliverToBoxAdapter(
            child: MeasurementSiteChips(
              selected: site,
              onSelected: (s) => ref.read(selectedMeasurementSiteProvider.notifier).select(s),
            ),
          ),
        ),
        SliverPadding(
          padding: gutter.copyWith(top: AppSpacing.s16),
          sliver: SliverToBoxAdapter(child: _SiteCard(site: site, entries: forSite)),
        ),
        if (forSite.isNotEmpty) ...[
          SliverPadding(
            padding: gutter.copyWith(top: AppSpacing.s24, bottom: AppSpacing.s8),
            sliver: SliverToBoxAdapter(child: SectionLabel(l10n.bodyMeasurementsHistoryLabel)),
          ),
          SliverPadding(
            padding: gutter.copyWith(bottom: bottomPad),
            sliver: SliverList.builder(
              itemCount: forSite.length,
              itemBuilder: (context, i) => GroupedListItem(
                first: i == 0,
                last: i == forSite.length - 1,
                dividerInset: AppSpacing.s16,
                child: _HistoryRow(
                  entry: forSite[i],
                  delta: i + 1 < forSite.length ? forSite[i].valueCm - forSite[i + 1].valueCm : null,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Latest value, its change, and the chart for one site.
class _SiteCard extends ConsumerWidget {
  const _SiteCard({required this.site, required this.entries});

  final MeasurementSite site;
  final List<BodyMeasurement> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final chart = ref.watch(measurementChartDataProvider);

    if (entries.isEmpty) {
      return LifeyCard.hero(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
          child: Center(
            child: Text(
              l10n.bodyMeasurementsNoSiteData,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: p.text2),
            ),
          ),
        ),
      );
    }

    final latest = entries.first;
    final change = entries.length > 1 ? latest.valueCm - entries[1].valueCm : null;
    return LifeyCard.hero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MetricValue(value: f.decimal(latest.valueCm, 1), unit: 'cm', size: 48),
              const Spacer(),
              if (change != null) DeltaChip.signed(value: change),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          chart.when(
            data: (points) => points.length < 2
                ? const SizedBox.shrink()
                : TimeSeriesChart(
                    points: points,
                    dateLabelBuilder: f.shortDate,
                    valueLabelBuilder: (v) => l10n.bodyMeasurementCmValue(f.decimal(v, 1)),
                    axisLabelBuilder: (v) => f.decimal(v, 1),
                    accentColor: context.metricColors.weight,
                    gradientFill: true,
                    showPoints: false,
                    highlightLast: true,
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

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.entry, required this.delta});

  final BodyMeasurement entry;

  /// Change vs the previous (older) entry for this site; null for the oldest.
  final double? delta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final d = entry.date.toLocal();

    return Dismissible(
      key: ValueKey('measurement-${entry.clientId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.s16),
        color: context.metricColors.negative,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(bodyMeasurementControllerProvider.notifier).remove(entry.clientId);
        AppSnackbar.showInfo(context, title: l10n.bodyMeasurementDeletedMessage);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MetricValue(value: f.decimal(entry.valueCm, 1), unit: 'cm', size: 19),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    '${f.weekdayShort(d)}, ${f.shortDate(d)}',
                    style: t.bodyMedium!.copyWith(fontWeight: FontWeight.w500, color: p.text2),
                  ),
                ],
              ),
            ),
            if (delta != null) DeltaChip.signed(value: delta!),
          ],
        ),
      ),
    );
  }
}
