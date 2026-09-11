import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';

/// A dated reading in a history list: "Jul 8, 2026 … 8 214".
typedef HistoryRow = ({String label, String value});

/// The plain "what was logged, and when" list under the steps and weight
/// charts. Newest first, and with no row affordances at all — these tabs are
/// read-only (frame C2).
class HistoryCard extends StatelessWidget {
  const HistoryCard({super.key, required this.title, required this.rows});

  final String title;
  final List<HistoryRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    row.value,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
