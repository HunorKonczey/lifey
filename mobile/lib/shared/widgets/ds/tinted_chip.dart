import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';

/// A metric-tinted status chip — "100 g to go", "🏆 2 PRs", "Weigh-in due"
/// (design system v2, D-R0.4; docs/redesign/77-mobile-redesign-plan.md R0.7).
///
/// The one place a tinted chip is built, so the contrast rule can't be
/// broken at a call site: the background is [color] at 16 % in dark and 12 %
/// in light, the text is [color] itself. Pass the *theme's* metric colour
/// (`context.metricColors.x`), never a hard-coded one — the light set is the
/// dark-toned, text-safe variant that keeps these chips at AA
/// (test/core/theme/contrast_test.dart).
///
/// Informational, not interactive; for filters use the chip theme (R0.8).
class TintedChip extends StatelessWidget {
  const TintedChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.size = TintedChipSize.small,
    this.semanticsLabel,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final TintedChipSize size;

  /// What a screen reader says instead of [label] — e.g. "2 personal
  /// records" for "🏆 2 PRs".
  final String? semanticsLabel;

  /// Background alpha of the tint per theme.
  static double tintAlpha(Brightness brightness) => brightness == Brightness.dark ? 0.16 : 0.12;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final small = size == TintedChipSize.small;
    final fontSize = small ? 12.0 : 13.0;
    return Container(
      constraints: BoxConstraints(minHeight: small ? 26 : 32),
      padding: EdgeInsets.symmetric(horizontal: small ? 10 : 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: tintAlpha(brightness)),
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 1, color: color),
            const SizedBox(width: AppSpacing.s4),
          ],
          Flexible(
            child: Text(
              label,
              semanticsLabel: semanticsLabel,
              style: TextStyle(
                fontFamily: AppType.fontFamily,
                fontSize: fontSize,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: AppType.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum TintedChipSize {
  /// 26 px — inside rows and tiles (the screen canvases).
  small,

  /// 32 px — standalone (the design-system showcase row).
  medium,
}
