import 'package:flutter/material.dart';

/// Typography helpers outside the Material [TextTheme] slots (design system
/// v2, docs/redesign/77-mobile-redesign-plan.md D-R0.7 / D-R0.8).
///
/// The [TextTheme] in app_theme.dart carries the design's named roles. What
/// doesn't fit a slot lives here: hero numbers at sizes off the scale (34 in
/// the calorie ring, 44 rest timer, 64 current weight, 104 moving time…), the
/// caps section label, and the "numbers don't grow with dynamic type" rule.
abstract final class AppType {
  static const String fontFamily = 'PlusJakartaSans';

  /// Every number is set with tabular figures so counters and stopwatches
  /// don't jitter as digits change. All five bundled weights carry `tnum`.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// Size of a unit next to its number, relative to the number ("1 739 kcal":
  /// the design puts the unit at 40–45 %).
  static const double unitScale = 0.42;

  /// Hero / metric number at an arbitrary [size]: the display family — 800,
  /// tracking −3 %, line height 1, tabular. Clamp its text scaling with
  /// [noScale] (MetricValue does).
  static TextStyle number(double size, {FontWeight weight = FontWeight.w800, Color? color}) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        height: 1,
        letterSpacing: -0.03 * size,
        fontFeatures: tabular,
        color: color,
      );

  /// The unit beside a [number] of [numberSize]. Tracking is reset to 0: the
  /// unit is usually a child span of the number and would otherwise inherit
  /// its −3 %, which at 28–34 px eats the space ("1 739kcal"). A canvas that
  /// sets a unit off the 42 % rule (the cardio hero's 14 px "bpm" after a 24 px
  /// number) passes its [size] explicitly.
  static TextStyle unit(double numberSize, {Color? color, double? size}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: size ?? numberSize * unitScale,
        fontWeight: FontWeight.w600,
        height: 1,
        letterSpacing: 0,
        color: color,
      );

  /// 12 / 16 · 700 · +8 % — the only style that is set in CAPS, and only for
  /// section labels ("TODAY'S MEALS"). Kept out of `labelSmall`, which also
  /// serves ~50 non-caps small labels that the tracking would spread out.
  static TextStyle sectionLabel({Color? color}) => TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 16 / 12,
        letterSpacing: 0.08 * 12,
        color: color,
      );

  /// The ambient text scaler capped at 1.0: display-size numbers stay put
  /// under dynamic type while body text and labels grow (tested to 130 %).
  static TextScaler noScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1);
}
