import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../domain/metric_summary.dart';
import '../../domain/stat_metric.dart';
import '../stat_format.dart';

/// Up to three small figures under the chart — "Lowest / Highest / Days on
/// target" — chosen per metric by [summaryFor].
class StatSideStats extends StatelessWidget {
  const StatSideStats({super.key, required this.metric, required this.sides});

  final StatMetric metric;
  final List<StatSide> sides;

  @override
  Widget build(BuildContext context) {
    if (sides.isEmpty) return const SizedBox.shrink();
    final fmt = StatFormat(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, side) in sides.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: _SideTile(label: fmt.sideLabel(side.kind), value: fmt.sideValue(metric, side)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SideTile extends StatelessWidget {
  const _SideTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return LifeyCard.nested(
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Semantics(
        container: true,
        label: '$label, $value',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.labelMedium!.copyWith(color: p.text2)),
            const SizedBox(height: AppSpacing.s8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, maxLines: 1, textScaler: AppType.noScale(context), style: AppType.number(20, color: p.text)),
            ),
          ],
        ),
      ),
    );
  }
}
