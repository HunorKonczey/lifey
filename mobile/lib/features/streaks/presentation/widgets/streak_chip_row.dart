import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/streak.dart';

/// Compact row of streak chips shown on the dashboard, one per daily goal
/// that's actually set (see `streaksProvider`) — absent entirely when no
/// goal is set, so a brand-new user's dashboard looks unchanged.
///
/// [onTap] opens the weekly recap screen (`/recap`) — optional so the widget
/// still renders standalone in isolation (e.g. tests) without a router.
class StreakChipRow extends StatelessWidget {
  const StreakChipRow({super.key, required this.streaks, this.onTap});

  final List<Streak> streaks;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (streaks.isEmpty) return const SizedBox.shrink();

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < streaks.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _StreakChip(streak: streaks[i]),
        ],
      ],
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pill,
      child: row,
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});

  final Streak streak;

  String _metricLabel(AppLocalizations l10n) => switch (streak.metric) {
        StreakMetric.calories => l10n.streakMetricCalories,
        StreakMetric.steps => l10n.streakMetricSteps,
        StreakMetric.water => l10n.streakMetricWater,
      };

  Color _metricColor(AppMetricColors mc) => switch (streak.metric) {
        StreakMetric.calories => mc.calories,
        StreakMetric.steps => mc.steps,
        StreakMetric.water => mc.water,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mc = context.metricColors;
    final l10n = AppLocalizations.of(context)!;
    final metricColor = _metricColor(mc);

    // Three visual states: no streak yet (muted), a streak alive but today
    // not yet met (subdued metric color — "still alive, act today"), and
    // today already met (full metric color).
    final Color flameColor;
    final FontWeight countWeight;
    if (!streak.isActive) {
      flameColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45);
      countWeight = FontWeight.w600;
    } else if (streak.todayMet) {
      flameColor = metricColor;
      countWeight = FontWeight.w800;
    } else {
      flameColor = metricColor.withValues(alpha: 0.55);
      countWeight = FontWeight.w700;
    }

    final tooltip = streak.isActive
        ? l10n.streakActiveTooltip(streak.current, _metricLabel(l10n))
        : l10n.streakNotStartedTooltip(_metricLabel(l10n));

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: AppRadius.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department, size: 16, color: flameColor),
            const SizedBox(width: 4),
            // A brief scale pop when the count changes — e.g. logging a
            // glass of water that ticks the streak up while the dashboard
            // is visible — is enough celebration for v1 (no confetti dep).
            AnimatedSwitcher(
              duration: AppDuration.fast,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Text(
                '${streak.current}',
                key: ValueKey(streak.current),
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: countWeight,
                  color: theme.colorScheme.onSurface,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
