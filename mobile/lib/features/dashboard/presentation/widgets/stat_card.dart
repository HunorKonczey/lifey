import 'package:flutter/material.dart';

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
  final Color? color;

  /// Optional 0..1+ share of a daily goal, rendered as a small bar at the
  /// bottom. Values above 1 are clamped for the bar but still count as reached.
  final double? ratio;

  /// Whether [ratio] has reached (or exceeded) 1.0 — shows a small badge next
  /// to the value and recolors the bar according to [goalTone].
  final bool goalReached;
  final GoalTone goalTone;

  /// When set, the whole card becomes tappable (e.g. to jump to that feature's tab).
  final VoidCallback? onTap;

  /// Optional small widget shown on the right of the label row (e.g. a trend arrow).
  final Widget? trailing;

  Color _toneColor() {
    switch (goalTone) {
      case GoalTone.positive:
        return Colors.green;
      case GoalTone.negative:
        return Colors.deepOrange;
      case GoalTone.neutral:
        return Colors.blueGrey;
    }
  }

  IconData get _toneIcon {
    switch (goalTone) {
      case GoalTone.positive:
        return Icons.check_circle;
      case GoalTone.negative:
        return Icons.error;
      case GoalTone.neutral:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    final toneColor = _toneColor();
    final barColor = goalReached ? toneColor : accent;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: accent),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold, color: accent),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 4),
                    Text(unit!, style: theme.textTheme.bodySmall),
                  ],
                  if (goalReached) ...[
                    const SizedBox(width: 6),
                    Icon(_toneIcon, size: 16, color: toneColor),
                  ],
                ],
              ),
              if (ratio != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio!.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: barColor.withValues(alpha: 0.15),
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
