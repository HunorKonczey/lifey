import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/card_edge_painter.dart';
import '../../../../shared/widgets/ds/pressable.dart';
import '../../domain/streak.dart';

/// The dashboard's streak strip — one 44 px pill on the card surface with an
/// icon + count per streak and a primary "Week in review ›" at the end that
/// opens the weekly recap (docs/redesign/77-mobile-redesign-plan.md R1.2,
/// canvas Lifey 1 top: "A streakek jelentést kapnak — a három szám nélküli
/// chip helyett egy sor ikonnal, és a Heti összefoglaló felirat jelzi, hogy
/// koppintható").
///
/// One item per streak in [streaks] (see `streaksProvider`): flame =
/// calories, foot = steps, drop = water, dumbbell = workouts. Absent
/// entirely when [streaks] is empty. [onTap] is optional so the widget still
/// renders standalone (e.g. in tests) without a router.
class StreakChipRow extends StatelessWidget {
  const StreakChipRow({super.key, required this.streaks, this.onTap});

  final List<Streak> streaks;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (streaks.isEmpty) return const SizedBox.shrink();

    final p = context.palette;
    final e = context.elevation;
    final l10n = AppLocalizations.of(context)!;
    final t = Theme.of(context).textTheme;
    const radius = AppRadius.pill;

    final strip = DecoratedBox(
      decoration: BoxDecoration(color: p.card, borderRadius: radius, boxShadow: e.e1),
      child: CustomPaint(
        foregroundPainter: CardEdgePainter(color: e.cardEdge, borderRadius: radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: e.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  for (final streak in streaks) _StreakItem(streak: streak),
                  Expanded(
                    child: onTap == null
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(left: AppSpacing.s8, right: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      l10n.streakStripWeekInReview,
                                      maxLines: 2,
                                      textAlign: TextAlign.end,
                                      style: t.bodySmall!.copyWith(fontWeight: FontWeight.w700, height: 1.2, color: Theme.of(context).colorScheme.primary),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded,
                                      size: 20, color: Theme.of(context).colorScheme.primary),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Pressable(
      onTap: onTap,
      semanticsLabel: l10n.streakStripWeekInReview,
      child: strip,
    );
  }
}

class _StreakItem extends StatelessWidget {
  const _StreakItem({required this.streak});

  final Streak streak;

  String _metricLabel(AppLocalizations l10n) => switch (streak.metric) {
        StreakMetric.calories => l10n.streakMetricCalories,
        StreakMetric.steps => l10n.streakMetricSteps,
        StreakMetric.water => l10n.streakMetricWater,
        StreakMetric.workout => l10n.streakMetricWorkout,
      };

  IconData get _icon => switch (streak.metric) {
        StreakMetric.calories => Icons.local_fire_department_rounded,
        StreakMetric.steps => Icons.directions_walk_rounded,
        StreakMetric.water => Icons.water_drop_rounded,
        StreakMetric.workout => Icons.fitness_center_rounded,
      };

  Color _metricColor(BuildContext context, AppMetricColors mc) => switch (streak.metric) {
        StreakMetric.calories => mc.calories,
        StreakMetric.steps => mc.steps,
        StreakMetric.water => mc.water,
        // No single existing metric colour represents "a workout" (strength
        // and cardio sessions each have their own accent) — the brand olive
        // is the neutral choice, and the canvas draws the dumbbell in it.
        StreakMetric.workout => Theme.of(context).colorScheme.primary,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mc = context.metricColors;
    final l10n = AppLocalizations.of(context)!;
    final t = Theme.of(context).textTheme;
    final metricColor = _metricColor(context, mc);

    // Three visual states: no streak yet (muted, canvas "0" in text-3 / text-2),
    // a streak alive but today not yet met (subdued metric colour — "still
    // alive, act today"), and today already met (full metric colour).
    final Color iconColor;
    final Color countColor;
    if (!streak.isActive) {
      iconColor = p.text3;
      countColor = p.text2;
    } else if (streak.todayMet) {
      iconColor = metricColor;
      countColor = p.text;
    } else {
      iconColor = metricColor.withValues(alpha: 0.55);
      countColor = p.text;
    }

    final tooltip = streak.isActive
        ? l10n.streakActiveTooltip(streak.current, _metricLabel(l10n))
        : l10n.streakNotStartedTooltip(_metricLabel(l10n));

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 18, color: iconColor),
            const SizedBox(width: AppSpacing.s4),
            // A brief scale pop when the count changes — e.g. logging a
            // glass of water that ticks the streak up while the dashboard
            // is visible — is enough celebration for v1 (no confetti dep).
            AnimatedSwitcher(
              duration: AppMotion.of(context, AppMotion.tap),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Text(
                '${streak.current}',
                key: ValueKey(streak.current),
                style: t.labelLarge!.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1,
                  fontFeatures: AppType.tabular,
                  color: countColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
