import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Spacing — 4pt base grid
// ---------------------------------------------------------------------------

abstract final class AppSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
}

// ---------------------------------------------------------------------------
// Radius scale
// ---------------------------------------------------------------------------

abstract final class AppRadius {
  /// 8 — small chips, tags, inner elements
  static const double sm = 8;

  /// 16 — medium buttons, smaller cards
  static const double md = 16;

  /// 18 — inputs, FABs, action rows
  static const double input = 18;

  /// 20 — list-tile cards
  static const double card = 20;

  /// 24 — large stat cards, chart cards
  static const double lg = 24;

  /// 28–30 — nav bar (floating)
  static const double nav = 28;

  /// Stadium — pill shapes (chips, segmented, collapsed nav)
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get inputAll => BorderRadius.circular(input);
  static BorderRadius get cardAll => BorderRadius.circular(card);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get navAll => BorderRadius.circular(nav);
}

// ---------------------------------------------------------------------------
// Motion
// ---------------------------------------------------------------------------

abstract final class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);

  /// Nav collapse — slightly longer for the spring feel
  static const Duration collapse = Duration(milliseconds: 380);
}

abstract final class AppCurve {
  /// Standard emphasized easing for most transitions
  static const Curve standard = Curves.easeInOut;

  /// Spring-like easing for the nav collapse/expand
  /// Matches: cubic-bezier(.2,.8,.2,1) from the design prototype
  static const Curve collapse = Cubic(0.2, 0.8, 0.2, 1.0);
}

// ---------------------------------------------------------------------------
// Metric accent colors
// Dual-value (dark / light) via ThemeExtension so they're theme-aware.
// ---------------------------------------------------------------------------

@immutable
class AppMetricColors extends ThemeExtension<AppMetricColors> {
  const AppMetricColors({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.steps,
    required this.weight,
    required this.water,
    required this.heart,
    required this.positive,
    required this.negative,
  });

  final Color calories;
  final Color protein;
  final Color carbs;
  final Color fat;
  final Color steps;
  final Color weight;
  final Color water;
  final Color heart;

  /// Positive goal state (e.g. protein reached)
  final Color positive;

  /// Negative / over-budget goal state (e.g. calories exceeded)
  final Color negative;

  // Dark variants
  static const AppMetricColors dark = AppMetricColors(
    calories: Color(0xFFE0915A),
    protein: Color(0xFF9DAE6B),
    carbs: Color(0xFFD8B35A),
    fat: Color(0xFF8E8EC4),
    steps: Color(0xFFB08AC8),
    weight: Color(0xFF8AA0B4),
    water: Color(0xFF6FA8C4),
    heart: Color(0xFFC46A6A),
    positive: Color(0xFF9DAE6B),
    negative: Color(0xFFE08A52),
  );

  // Light variants
  static const AppMetricColors light = AppMetricColors(
    calories: Color(0xFFD27A3E),
    protein: Color(0xFF586E38),
    carbs: Color(0xFFB8902F),
    fat: Color(0xFF6A6AB0),
    steps: Color(0xFF8A6AB0),
    weight: Color(0xFF5E7A92),
    water: Color(0xFF4E8AA8),
    heart: Color(0xFFC46A6A),
    positive: Color(0xFF4A7A52),
    negative: Color(0xFFE08A52),
  );

  @override
  AppMetricColors copyWith({
    Color? calories,
    Color? protein,
    Color? carbs,
    Color? fat,
    Color? steps,
    Color? weight,
    Color? water,
    Color? heart,
    Color? positive,
    Color? negative,
  }) =>
      AppMetricColors(
        calories: calories ?? this.calories,
        protein: protein ?? this.protein,
        carbs: carbs ?? this.carbs,
        fat: fat ?? this.fat,
        steps: steps ?? this.steps,
        weight: weight ?? this.weight,
        water: water ?? this.water,
        heart: heart ?? this.heart,
        positive: positive ?? this.positive,
        negative: negative ?? this.negative,
      );

  @override
  AppMetricColors lerp(AppMetricColors? other, double t) {
    if (other == null) return this;
    return AppMetricColors(
      calories: Color.lerp(calories, other.calories, t)!,
      protein: Color.lerp(protein, other.protein, t)!,
      carbs: Color.lerp(carbs, other.carbs, t)!,
      fat: Color.lerp(fat, other.fat, t)!,
      steps: Color.lerp(steps, other.steps, t)!,
      weight: Color.lerp(weight, other.weight, t)!,
      water: Color.lerp(water, other.water, t)!,
      heart: Color.lerp(heart, other.heart, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
    );
  }
}

/// Convenience extension — read metric colors from any [BuildContext].
///
/// ```dart
/// context.metricColors.calories
/// ```
extension AppMetricColorsX on BuildContext {
  AppMetricColors get metricColors =>
      Theme.of(this).extension<AppMetricColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppMetricColors.dark
          : AppMetricColors.light);
}
