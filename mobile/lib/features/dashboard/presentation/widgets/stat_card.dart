import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// How a [StatCard] should color its "goal reached" indicator and bar.
enum GoalTone {
  /// Reaching/exceeding the goal is good (e.g. a protein target).
  positive,

  /// Exceeding the goal is a mild warning (e.g. a calorie limit).
  negative,

  /// Reaching the goal is neither good nor bad, just informational.
  neutral,
}

/// Small labelled metric tile used across the dashboard.
///
/// Visual anatomy:
///   [icon badge]  label text              [trailing?]
///   value  unit  [✓ if goalReached]
///   ████░░░░░░░░  progress bar (if ratio set)
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.color,
    this.ratio,
    this.goalReached = false,
    this.goalTone = GoalTone.neutral,
    this.onTap,
    this.trailing,
  });

  final String label;
  final String value;
  final String? unit;
  final IconData? icon;

  /// Explicit accent color. Falls back to [ColorScheme.primary] when null.
  final Color? color;

  /// Optional 0..1+ share of a daily goal, rendered as a pill bar at the
  /// bottom. Values above 1 are clamped for the bar but still count as reached.
  final double? ratio;

  /// Whether [ratio] has reached (or exceeded) 1.0 — shows a small badge next
  /// to the value and recolors the bar according to [goalTone].
  final bool goalReached;
  final GoalTone goalTone;

  /// When set, the whole card becomes tappable (e.g. to jump to a feature tab).
  final VoidCallback? onTap;

  /// Optional small widget shown on the right of the label row (e.g. trend arrow).
  final Widget? trailing;

  Color _toneColor(BuildContext context) => switch (goalTone) {
        GoalTone.positive => context.metricColors.positive,
        GoalTone.negative => context.metricColors.negative,
        GoalTone.neutral => Theme.of(context).colorScheme.primary,
      };

  IconData get _toneIcon => switch (goalTone) {
        GoalTone.positive => Icons.check_circle,
        GoalTone.negative => Icons.error,
        GoalTone.neutral => Icons.check_circle_outline,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    final toneColor = _toneColor(context);
    final barColor = goalReached ? toneColor : accent;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Label row ─────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    _IconBadge(icon: icon!, color: accent),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 10),
              // ── Value row ─────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: accent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (goalReached) ...[
                    const SizedBox(width: 6),
                    Icon(_toneIcon, size: 14, color: toneColor),
                  ],
                ],
              ),
              // ── Progress bar ──────────────────────────────────────────
              if (ratio != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: ratio!.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: barColor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Icon badge — accent-tinted rounded square behind the icon
// ---------------------------------------------------------------------------

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
