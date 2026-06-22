import 'package:flutter/material.dart';

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

  static const _accent = Colors.lightBlue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasGoal = goalLiters != null && goalLiters! > 0;
    final ratio = hasGoal ? currentLiters / goalLiters! : null;
    final percentLabel = ratio != null ? '${(ratio * 100).round()}%' : null;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _accent.withValues(alpha: 0.15),
                  child: const Icon(Icons.water_drop, color: _accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.waterLabel,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            hasGoal
                                ? l10n.waterAmountLabel(currentLiters.toStringAsFixed(2),
                                    goalLiters!.toStringAsFixed(2))
                                : l10n.waterAmountNoGoalLabel(currentLiters.toStringAsFixed(2)),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (percentLabel != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              percentLabel,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: _accent, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  tooltip: l10n.logWaterTitle,
                ),
              ],
            ),
            if (ratio != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: _accent.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(_accent),
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                l10n.setDailyGoalMessage,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
