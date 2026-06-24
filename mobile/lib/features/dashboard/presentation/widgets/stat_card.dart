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
/// Two layouts:
///
/// Standard (default):
///   [icon]  label text              [trailing?]
///   value  unit  [✓ if goalReached]  [valueTrailing?]
///   subtitle?
///   ████░░░░░░░░  progress bar (if ratio set)
///
/// Compact (macro cards):
///   [icon]
///   value  unit
///   label
///   ████░░  progress bar
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
    this.valueTrailing,
    this.subtitle,
    this.compact = false,
    this.badgeText,
    this.badgeColor,
  });

  final String label;
  final String value;
  final String? unit;
  final IconData? icon;

  /// Explicit accent color. Falls back to [ColorScheme.primary] when null.
  final Color? color;

  /// Optional 0..1+ share of a daily goal rendered as a pill bar at the
  /// bottom. Values above 1 are clamped for the bar but still count as reached.
  final double? ratio;

  final bool goalReached;
  final GoalTone goalTone;

  final VoidCallback? onTap;

  /// Small widget on the right of the label row (standard layout only).
  final Widget? trailing;

  /// Small widget placed after value+unit in the value row.
  final Widget? valueTrailing;

  /// Secondary line shown below the value row (e.g. "kg · vs prev entry").
  final String? subtitle;

  /// When true, uses the compact macro layout: icon → value → label → bar.
  final bool compact;

  /// Optional pill badge text (e.g. "320 left", "+180 over", "25g more").
  /// Shown trailing in the label row (standard) or below the label (compact).
  final String? badgeText;

  /// Accent color for the badge pill. Falls back to [color] when null.
  final Color? badgeColor;

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
          child: compact
              ? _CompactLayout(
                  icon: icon,
                  accent: accent,
                  value: value,
                  unit: unit,
                  label: label,
                  goalReached: goalReached,
                  toneIcon: _toneIcon,
                  toneColor: toneColor,
                  barColor: barColor,
                  ratio: ratio,
                  badgeText: badgeText,
                  badgeColor: badgeColor ?? accent,
                )
              : _StandardLayout(
                  icon: icon,
                  accent: accent,
                  value: value,
                  unit: unit,
                  label: label,
                  goalReached: goalReached,
                  toneIcon: _toneIcon,
                  toneColor: toneColor,
                  barColor: barColor,
                  ratio: ratio,
                  trailing: trailing,
                  valueTrailing: valueTrailing,
                  subtitle: subtitle,
                  badgeText: badgeText,
                  badgeColor: badgeColor ?? accent,
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Standard layout — icon+label row, then value row, then optional bar
// ---------------------------------------------------------------------------

class _StandardLayout extends StatelessWidget {
  const _StandardLayout({
    required this.icon,
    required this.accent,
    required this.value,
    required this.unit,
    required this.label,
    required this.goalReached,
    required this.toneIcon,
    required this.toneColor,
    required this.barColor,
    required this.ratio,
    this.trailing,
    this.valueTrailing,
    this.subtitle,
    this.badgeText,
    required this.badgeColor,
  });

  final IconData? icon;
  final Color accent;
  final String value;
  final String? unit;
  final String label;
  final bool goalReached;
  final IconData toneIcon;
  final Color toneColor;
  final Color barColor;
  final double? ratio;
  final Widget? trailing;
  final Widget? valueTrailing;
  final String? subtitle;
  final String? badgeText;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Label row ─────────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon!, size: 20, color: accent),
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
            if (badgeText != null) _MetricBadge(text: badgeText!, color: badgeColor),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 10),
        // ── Value row ─────────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
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
              Icon(toneIcon, size: 14, color: toneColor),
            ],
            if (valueTrailing != null) ...[
              const SizedBox(width: 6),
              valueTrailing!,
            ],
          ],
        ),
        // ── Subtitle ──────────────────────────────────────────────────────
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
        // ── Progress bar ──────────────────────────────────────────────────
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
    );
  }
}

// ---------------------------------------------------------------------------
// Compact layout — icon top, value, label below value, bar
// Used for macro cards (protein / carbs / fat)
// ---------------------------------------------------------------------------

// _MetricBadge is defined at the bottom of this file.

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({
    required this.icon,
    required this.accent,
    required this.value,
    required this.unit,
    required this.label,
    required this.goalReached,
    required this.toneIcon,
    required this.toneColor,
    required this.barColor,
    required this.ratio,
    this.badgeText,
    required this.badgeColor,
  });

  final IconData? icon;
  final Color accent;
  final String value;
  final String? unit;
  final String label;
  final bool goalReached;
  final IconData toneIcon;
  final Color toneColor;
  final Color barColor;
  final double? ratio;
  final String? badgeText;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon!, size: 18, color: accent),
        const SizedBox(height: 7),
        // ── Value row ─────────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Text(
                unit!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (goalReached) ...[
              const SizedBox(width: 4),
              Icon(toneIcon, size: 12, color: toneColor),
            ],
          ],
        ),
        const SizedBox(height: 2),
        // ── Label ─────────────────────────────────────────────────────────
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        // Badge slot is always rendered (even when invisible) so all compact
        // cards in a row stay the same height.
        const SizedBox(height: 5),
        Opacity(
          opacity: badgeText != null ? 1.0 : 0.0,
          child: _MetricBadge(text: badgeText ?? '', color: badgeColor),
        ),
        // ── Progress bar ──────────────────────────────────────────────────
        if (ratio != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio!.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: barColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Metric badge — small pill used for "320 left", "+180 over", "25g more"
// ---------------------------------------------------------------------------

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.0,
        ),
      ),
    );
  }
}
