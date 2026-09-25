import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/delta_chip.dart';
import '../../../../shared/widgets/ds/metric_value.dart';
import '../../application/weight_headline.dart';

/// The hero of the weight screen (canvas Lifey 4 › 4.1): "Current · today
/// 07:02" over the weight at 64 px, and the two changes beside it — "↓ 0.1
/// today" and "↓ 1.4 in 30 d" (docs/redesign/77-mobile-redesign-plan.md R4.1).
///
/// The chips are neutral (the weight colour) unless a goal gives a change a
/// meaning: the 30-day change is the improvement green when it moved toward
/// the goal, the calorie orange when it moved away. The number and the chips
/// share a `Wrap`, so the chips drop under the number when there is no room —
/// a Hungarian label or a big text size never squeezes the hero.
class WeightHeroHeader extends StatelessWidget {
  const WeightHeroHeader({super.key, required this.headline});

  final WeightHeadline headline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final mc = context.metricColors;
    final t = Theme.of(context).textTheme;
    final latest = headline.latest;

    final overline = headline.latestIsToday
        ? l10n.weightCurrentToday(f.time(latest.recordedAt.toLocal()))
        : l10n.weightCurrentOn(f.shortDate(latest.date.toLocal()));

    final sinceLast = headline.sinceLastKg;
    final change30d = headline.change30dKg;
    final goodDirection = headline.goalIsLoss;
    Color? toward(double delta) {
      if (goodDirection == null || delta == 0) return null;
      return (goodDirection ? delta < 0 : delta > 0) ? mc.improvement : mc.increase;
    }

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.start,
      spacing: AppSpacing.s12,
      runSpacing: AppSpacing.s12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(overline, style: t.bodyMedium!.copyWith(fontSize: 15, fontWeight: FontWeight.w500, color: p.text2)),
            const SizedBox(height: AppSpacing.s8),
            MetricValue(value: f.decimal(latest.weight, 1), unit: 'kg', size: 64),
          ],
        ),
        if (sinceLast != null || change30d != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sinceLast != null)
                DeltaChip.arrow(
                  value: sinceLast,
                  suffix: headline.latestIsToday ? l10n.weightDeltaToday : l10n.weightDeltaSinceLast,
                ),
              if (sinceLast != null && change30d != null) const SizedBox(height: AppSpacing.s8),
              if (change30d != null)
                DeltaChip.arrow(value: change30d, suffix: l10n.weightDelta30d, color: toward(change30d)),
            ],
          ),
      ],
    );
  }
}
