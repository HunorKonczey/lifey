import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// Prominent horizontal dashboard card: current water intake vs. the daily
/// goal, a progress bar, and a "+" action to log more.
class WaterCard extends StatelessWidget {
  const WaterCard({
    super.key,
    required this.currentLiters,
    required this.goalLiters,
    required this.onAdd,
  });

  final double currentLiters;
  final double? goalLiters;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final accent = context.metricColors.water; // #6FA8C4 dark / #4E8AA8 light
    final hasGoal = goalLiters != null && goalLiters! > 0;
    final ratio = hasGoal ? currentLiters / goalLiters! : null;
    final percentLabel = ratio != null ? '${(ratio * 100).round()}%' : null;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // ── Icon badge ─────────────────────────────────────────
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(Icons.water_drop, size: 22, color: accent),
                  ),
                ),
                const SizedBox(width: 12),

                // ── Label + value ──────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.waterLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            hasGoal
                                ? l10n.waterAmountLabel(
                                    currentLiters.toStringAsFixed(2),
                                    goalLiters!.toStringAsFixed(2),
                                  )
                                : l10n.waterAmountNoGoalLabel(
                                    currentLiters.toStringAsFixed(2),
                                  ),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (percentLabel != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              percentLabel,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // ── Add button — rounded square matching icon badge ────
                GestureDetector(
                  onTap: onAdd,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(Icons.add, size: 22, color: accent),
                    ),
                  ),
                ),
              ],
            ),

            // ── Progress bar / no-goal hint ────────────────────────────
            if (ratio != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: accent.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                l10n.setDailyGoalMessage,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
