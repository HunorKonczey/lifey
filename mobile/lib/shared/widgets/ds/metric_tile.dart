import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import 'lifey_card.dart';
import 'metric_bar.dart';

/// A metric tile — Water, Steps, Weight on the dashboard (design system v2
/// "METRIKACSEMPE"; docs/redesign/77-mobile-redesign-plan.md R0.9).
///
/// Card (padding 16, radius 22) with: a header of an 18 px filled icon in the
/// metric colour and a 13/600 label; the value at 26/800 with its unit or
/// "/ goal" at 13/600 beside it; then optionally a delta chip, a progress bar
/// and a secondary line. The value and its unit may wrap onto two lines
/// rather than truncate ("6 412 / 10 000" in Hungarian at 130 %); the number
/// itself never scales with dynamic type.
///
/// [onAction] adds the canvas's solid metric-coloured quick-add button in
/// the top corner (48 dp). [trailing] sits right of the value block in a
/// full-width tile (the weight sparkline).
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.unit,
    this.progress,
    this.delta,
    this.subline,
    this.trailing,
    this.onAction,
    this.actionIcon = Icons.add_rounded,
    this.actionTooltip,
    this.onTap,
    this.semanticsLabel,
  }) : assert(onAction == null || actionTooltip != null, 'an icon-only action needs a tooltip');

  final IconData icon;
  final String label;

  /// Formatted number — "0.99", "6 412".
  final String value;

  /// Unit or goal beside it — "kg", "/ 2.6 L", "of 10 000".
  final String? unit;
  final Color color;

  /// value / goal for the bar; null = no bar.
  final double? progress;

  /// Usually a DeltaChip, beside the value.
  final Widget? delta;

  /// Secondary line under everything — "Latest entry · today".
  final String? subline;

  final Widget? trailing;
  final VoidCallback? onAction;
  final IconData actionIcon;
  final String? actionTooltip;
  final VoidCallback? onTap;

  /// Read instead of the parts, e.g. "Water, 0.99 of 2.6 litres".
  final String? semanticsLabel;

  static const double valueSize = 26;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Fixed 32 px header with or without the quick-add button, so tiles
    // side by side line up; the button floats over the corner instead.
    final header = SizedBox(
      height: 32,
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: onAction != null ? 40 : 0),
            child: Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: p.text2)),
          ),
        ),
      ]),
    );

    final valueText = Text.rich(
      TextSpan(children: [
        TextSpan(text: value, style: AppType.number(valueSize, color: p.text).copyWith(letterSpacing: -0.02 * valueSize)),
        if (unit != null)
          TextSpan(
            text: ' $unit',
            style: TextStyle(fontFamily: AppType.fontFamily, fontSize: 13, fontWeight: FontWeight.w600, color: p.text2),
          ),
      ]),
      textScaler: AppType.noScale(context),
    );

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        const SizedBox(height: AppSpacing.s12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [valueText, if (delta != null) delta!],
              ),
              if (subline != null) ...[
                const SizedBox(height: 6),
                Text(subline!, style: Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 12, height: 1.3, color: p.text3)),
              ],
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: AppSpacing.s12), trailing!],
        ]),
        if (progress != null) ...[
          const SizedBox(height: AppSpacing.s12),
          MetricBar(progress: progress!, color: color),
        ],
      ],
    );

    final body = Stack(
      clipBehavior: Clip.none,
      children: [
        // With a summary label the parts aren't read one by one; the action
        // button stays reachable either way.
        ExcludeSemantics(excluding: semanticsLabel != null, child: column),
        if (onAction != null)
          Positioned(
            // The canvas lets the button overhang the card padding.
            top: -8,
            right: -8,
            child: IconButton(
              onPressed: onAction,
              tooltip: actionTooltip,
              icon: Icon(actionIcon, size: 24),
              style: IconButton.styleFrom(
                fixedSize: const Size.square(48),
                backgroundColor: color,
                foregroundColor: dark ? p.bg : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.controlAll),
              ),
            ),
          ),
      ],
    );

    final card = LifeyCard(onTap: onTap, child: body);
    if (semanticsLabel == null) return card;
    // explicitChildNodes keeps the quick-add button its own node instead of
    // merging its tap into the summary.
    return Semantics(label: semanticsLabel, container: true, explicitChildNodes: true, child: card);
  }
}
