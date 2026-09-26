import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../shared/widgets/ds/list_group.dart';
import '../../../../../shared/widgets/ds/metric_value.dart';
import '../../../../../shared/widgets/ds/section_label.dart';

/// A dated reading in a history list: "8 214" over "Jul 8, 2026", or "64.5 kg"
/// with the change since the reading before it.
class HistoryRow {
  const HistoryRow({required this.label, required this.value, this.unit, this.trailing});

  /// The date (or whatever names the reading), under the value.
  final String label;

  /// The formatted number.
  final String value;

  /// Written small beside the number — "kg".
  final String? unit;

  /// At the row's right edge — a `DeltaChip.signed` for weight.
  final Widget? trailing;
}

/// The plain "what was logged, and when" list under the steps and weight
/// charts (canvas Lifey 4's history rows, on the trainer side): a caps heading
/// over a `ListGroup`, newest first, with no row affordances at all — these tabs
/// are read-only (frame C2).
class HistoryCard extends StatelessWidget {
  const HistoryCard({super.key, required this.title, required this.rows});

  final String title;
  final List<HistoryRow> rows;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s8),
          child: SectionLabel(title),
        ),
        ListGroup(
          dividerInset: AppSpacing.s16,
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MetricValue(value: row.value, unit: row.unit, size: 19),
                          const SizedBox(height: AppSpacing.s4),
                          Text(row.label, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: p.text2)),
                        ],
                      ),
                    ),
                    if (row.trailing != null) ...[const SizedBox(width: AppSpacing.s12), row.trailing!],
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
