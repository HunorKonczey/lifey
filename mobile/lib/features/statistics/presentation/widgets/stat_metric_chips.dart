import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/stat_chart_data.dart';
import '../../application/stat_metric_controller.dart';
import '../../domain/stat_metric.dart';
import '../stat_format.dart';

/// The metric switcher: one chip per metric the person has data for, in a row
/// that scrolls sideways (canvas Lifey 4 › 5; docs/redesign/77-mobile-redesign-
/// plan.md R4.6). Replaces the popup menu — every metric is one tap away and
/// the selected one wears its own colour.
class StatMetricChips extends ConsumerWidget {
  const StatMetricChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(statMetricControllerProvider);
    final available = ref.watch(availableStatMetricsProvider);
    final pickable = available.isEmpty ? StatMetric.values.toSet() : available;

    // The selected metric may have no data any more (a kind filter narrowed
    // it away): fall back to the first one that has.
    if (!pickable.contains(selected)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(statMetricControllerProvider.notifier).select(pickable.first);
      });
    }
    final current = pickable.contains(selected) ? selected : pickable.first;

    return SizedBox(
      height: 44,
      // A plain scroll view, not a lazy list: the selected chip must exist to be
      // scrolled to when the metric was chosen elsewhere or fell back.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        child: Row(
          children: [
            for (final m in StatMetric.values)
              if (pickable.contains(m))
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.s8),
                  child: _MetricChip(
                    label: m.label(l10n),
                    color: statMetricColor(context, m),
                    selected: m == current,
                    onTap: () => ref.read(statMetricControllerProvider.notifier).select(m),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatefulWidget {
  const _MetricChip({required this.label, required this.color, required this.selected, required this.onTap});

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_MetricChip> createState() => _MetricChipState();
}

class _MetricChipState extends State<_MetricChip> {
  @override
  void initState() {
    super.initState();
    if (widget.selected) _reveal(animate: false);
  }

  @override
  void didUpdateWidget(_MetricChip old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) _reveal(animate: true);
  }

  /// Brings the selected chip into the row's view.
  void _reveal({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: animate ? AppMotion.of(context, AppMotion.page) : Duration.zero,
        curve: AppMotion.standard,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final color = widget.color;
    final selected = widget.selected;
    final onTap = widget.onTap;
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? color.withValues(alpha: 0.16) : p.card,
        shape: StadiumBorder(side: BorderSide(color: selected ? color : context.elevation.border, width: selected ? 1.5 : 1)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  label,
                  maxLines: 1,
                  style: t.labelLarge!.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? p.text : p.text2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
