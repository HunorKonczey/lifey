import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Spacing — 4pt base grid (docs/redesign/77-mobile-redesign-plan.md D-R0.6)
// ---------------------------------------------------------------------------

abstract final class AppSpacing {
  /// Icon ↔ label.
  static const double s4 = 4;

  /// Chip gap, tight group.
  static const double s8 = 8;

  /// List-row inner padding.
  static const double s12 = 12;

  /// Card inner padding.
  static const double s16 = 16;

  /// Screen side margin.
  static const double s20 = 20;

  /// Between cards.
  static const double s24 = 24;

  /// Between sections.
  static const double s32 = 32;

  /// Above a hero.
  static const double s40 = 40;

  /// Bottom of a screen, above the nav.
  static const double s56 = 56;

  /// Horizontal margin of every screen's content.
  static const double screen = s20;
}

// ---------------------------------------------------------------------------
// Radius scale — four steps + pill (D-R0.5)
// ---------------------------------------------------------------------------

abstract final class AppRadius {
  /// 8 — tag, set row.
  static const double tag = 8;

  /// 14 — input, button, icon holder.
  static const double control = 14;

  /// 22 — card.
  static const double card = 22;

  /// 30 — hero card, bottom sheet, bottom nav.
  static const double hero = 30;

  /// Stadium — chips, segmented control, nav pill.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  static BorderRadius get tagAll => BorderRadius.circular(tag);
  static BorderRadius get controlAll => BorderRadius.circular(control);
  static BorderRadius get cardAll => BorderRadius.circular(card);
  static BorderRadius get heroAll => BorderRadius.circular(hero);

  /// Radius of an element nested [inset] px inside a parent of radius
  /// [parent]: the design rule "beágyazott elem sugara = szülő − belső margó",
  /// so the two curves stay concentric.
  static double nested(double parent, double inset) =>
      parent - inset > 0 ? parent - inset : 0;
}

// ---------------------------------------------------------------------------
// Motion — v2 spec (D-R0.13)
// ---------------------------------------------------------------------------

abstract final class AppMotion {
  /// Tap feedback — card scales to 0.98.
  static const Duration tap = Duration(milliseconds: 100);

  /// Set-done tint + check.
  static const Duration setDone = Duration(milliseconds: 250);

  /// Page change — shared-axis X within a tab, fade-through between tabs.
  static const Duration page = Duration(milliseconds: 300);

  /// Bottom sheet slide-up.
  static const Duration sheet = Duration(milliseconds: 350);

  /// Main numbers rolling from the old to the new value.
  static const Duration countUp = Duration(milliseconds: 600);

  /// Ring and bar fill.
  static const Duration fill = Duration(milliseconds: 900);

  /// Delay between consecutive macro rings/bars.
  static const Duration stagger = Duration(milliseconds: 60);

  /// One-shot PR celebration.
  static const Duration celebration = Duration(milliseconds: 1200);

  /// Delay of the [index]-th element in a staggered group ("60 ms eltolással
  /// a makrók között").
  static Duration staggered(int index) => stagger * index;

  /// Most transitions — cubic(0.2, 0, 0, 1).
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// Elements entering (fills, sheets opening) — cubic(0.05, 0.7, 0.1, 1).
  static const Curve enter = Cubic(0.05, 0.7, 0.1, 1);

  /// Elements leaving — cubic(0.3, 0, 0.8, 0.15).
  static const Curve exit = Cubic(0.3, 0, 0.8, 0.15);

  /// [duration], or zero when the platform asks for reduced motion — then
  /// every animation becomes an instant cut and numbers sit on their final
  /// value. Every v2 animation reads its duration through this.
  static Duration of(BuildContext context, Duration duration) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? Duration.zero : duration;
}

// ---------------------------------------------------------------------------
// Elevation (R0.2)
// Dark: depth comes from surface tone; drop shadows only on floating layers,
// plus a 1 px top light edge on cards (drawn by CardEdgePainter — CSS's
// `inset 0 1px 0` has no BoxShadow equivalent). Light: white cards on a warm
// bg with a soft warm shadow instead of a border. Values are the ones the
// canvases use.
// ---------------------------------------------------------------------------

@immutable
class AppElevation extends ThemeExtension<AppElevation> {
  /// The lifted thumb of a segmented control / pill tab bar in the dark theme
  /// (the light theme uses [e1]): a soft black drop, 66 % opaque.
  static const List<BoxShadow> pillThumbDark = [
    BoxShadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 8),
  ];

  const AppElevation({
    required this.border,
    required this.cardEdge,
    required this.heroEdge,
    required this.floatEdge,
    required this.e1,
    required this.e2,
    required this.e3,
    required this.sheet,
  });

  /// e0 — a 1 px hairline ring, for flat elements that need an outline.
  final Color border;

  /// Top light edge of an e1 card (transparent in light).
  final Color cardEdge;

  /// Top light edge of an e2 hero / FAB (transparent in light).
  final Color heroEdge;

  /// Top light edge of an e3 floating layer (transparent in light).
  final Color floatEdge;

  /// e1 — card.
  final List<BoxShadow> e1;

  /// e2 — hero card, FAB.
  final List<BoxShadow> e2;

  /// e3 — bottom nav, floating bars; always with a [floatBlur] backdrop.
  final List<BoxShadow> e3;

  /// Bottom sheet — e3 cast upwards.
  final List<BoxShadow> sheet;

  /// Backdrop blur sigma under the bottom nav and floating bars.
  static const double floatBlur = 24;

  /// Backdrop blur sigma under the status-bar scrim.
  static const double scrimBlur = 20;

  static const AppElevation dark = AppElevation(
    border: Color(0x12F2F1E6), // rgba(242,241,230,0.07)
    cardEdge: Color(0x09FFFFFF), // rgba(255,255,255,0.035)
    heroEdge: Color(0x0DFFFFFF), // rgba(255,255,255,0.05)
    floatEdge: Color(0x12FFFFFF), // rgba(255,255,255,0.07)
    e1: [],
    e2: [
      BoxShadow(color: Color(0xCC000000), offset: Offset(0, 10), blurRadius: 24, spreadRadius: -12),
    ],
    e3: [
      BoxShadow(color: Color(0xE6000000), offset: Offset(0, 20), blurRadius: 40, spreadRadius: -12),
    ],
    sheet: [
      BoxShadow(color: Color(0x99000000), offset: Offset(0, -20), blurRadius: 40, spreadRadius: -12),
    ],
  );

  static const AppElevation light = AppElevation(
    border: Color(0x141C1D16), // rgba(28,29,22,0.08)
    cardEdge: Color(0x00FFFFFF),
    heroEdge: Color(0x00FFFFFF),
    floatEdge: Color(0x00FFFFFF),
    e1: [
      BoxShadow(color: Color(0x0D282614), offset: Offset(0, 1), blurRadius: 2),
      BoxShadow(color: Color(0x38282614), offset: Offset(0, 10), blurRadius: 24, spreadRadius: -16),
    ],
    e2: [
      BoxShadow(color: Color(0x0D282614), offset: Offset(0, 1), blurRadius: 2),
      BoxShadow(color: Color(0x38282614), offset: Offset(0, 10), blurRadius: 24, spreadRadius: -16),
    ],
    e3: [
      BoxShadow(color: Color(0x4D282614), offset: Offset(0, 16), blurRadius: 32, spreadRadius: -12),
    ],
    sheet: [
      BoxShadow(color: Color(0x4D282614), offset: Offset(0, -16), blurRadius: 32, spreadRadius: -12),
    ],
  );

  @override
  AppElevation copyWith({
    Color? border,
    Color? cardEdge,
    Color? heroEdge,
    Color? floatEdge,
    List<BoxShadow>? e1,
    List<BoxShadow>? e2,
    List<BoxShadow>? e3,
    List<BoxShadow>? sheet,
  }) =>
      AppElevation(
        border: border ?? this.border,
        cardEdge: cardEdge ?? this.cardEdge,
        heroEdge: heroEdge ?? this.heroEdge,
        floatEdge: floatEdge ?? this.floatEdge,
        e1: e1 ?? this.e1,
        e2: e2 ?? this.e2,
        e3: e3 ?? this.e3,
        sheet: sheet ?? this.sheet,
      );

  @override
  AppElevation lerp(AppElevation? other, double t) {
    if (other == null) return this;
    return AppElevation(
      border: Color.lerp(border, other.border, t)!,
      cardEdge: Color.lerp(cardEdge, other.cardEdge, t)!,
      heroEdge: Color.lerp(heroEdge, other.heroEdge, t)!,
      floatEdge: Color.lerp(floatEdge, other.floatEdge, t)!,
      e1: BoxShadow.lerpList(e1, other.e1, t)!,
      e2: BoxShadow.lerpList(e2, other.e2, t)!,
      e3: BoxShadow.lerpList(e3, other.e3, t)!,
      sheet: BoxShadow.lerpList(sheet, other.sheet, t)!,
    );
  }
}

/// Convenience extension — read elevation tokens from any [BuildContext].
extension AppElevationX on BuildContext {
  AppElevation get elevation =>
      Theme.of(this).extension<AppElevation>() ??
      (Theme.of(this).brightness == Brightness.dark ? AppElevation.dark : AppElevation.light);
}

// ---------------------------------------------------------------------------
// Semantic palette (design system v2)
// The tokens Material 3 has no slot for — three text tiers, the translucent
// `float` layer, the status-bar scrim — plus the surface ladder by its design
// names. The overlapping ones are also mapped into `ColorScheme` in
// app_theme.dart so stock Material widgets pick them up
// (docs/redesign/77-mobile-redesign-plan.md D-R0.2).
// ---------------------------------------------------------------------------

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.card,
    required this.nested,
    required this.control,
    required this.raised,
    required this.float,
    required this.scrim,
    required this.text,
    required this.text2,
    required this.text3,
    required this.hairline,
    required this.primaryTint,
    required this.onPrimaryTint,
    required this.role,
  });

  /// Scaffold background, the deepest layer.
  final Color bg;

  /// surface-1 — cards.
  final Color card;

  /// surface-2 — elements nested in a card, sheets, dialogs.
  final Color nested;

  /// surface-3 — chips, inputs, progress tracks.
  final Color control;

  /// One step above [control]. Not a design token — derived so the
  /// `surfaceContainerHighest` slot stays above `surfaceContainerHigh`.
  final Color raised;

  /// Translucent layer under the bottom nav and the header; always drawn
  /// with a backdrop blur.
  final Color float;

  /// Status-bar scrim behind scrolled content (bg at 88 %, blurred).
  final Color scrim;

  /// Primary text.
  final Color text;

  /// Secondary text — labels, units.
  final Color text2;

  /// Footnotes. Still AA on [bg] and [card], never used below 12 px.
  final Color text3;

  /// Row dividers and card hairlines. Not a design token — derived from the
  /// canvas's `rgba(242,241,230,0.07)` hairline (dark) and surface-3 (light).
  final Color hairline;

  /// Brand olive tint — avatar background, selected chip.
  final Color primaryTint;

  /// Text and icons on [primaryTint].
  final Color onPrimaryTint;

  /// Clay role mark ("TRAINER"); the same value as `ColorScheme.secondary`.
  final Color role;

  static const AppPalette dark = AppPalette(
    bg: Color(0xFF12130E),
    card: Color(0xFF1A1C15),
    nested: Color(0xFF22251C),
    control: Color(0xFF2C2F24),
    raised: Color(0xFF36392D),
    float: Color(0xD1282C20), // #282C20 at 82 %
    scrim: Color(0xE012130E), // bg at 88 %
    text: Color(0xFFF2F1E6),
    text2: Color(0xFFB6B5A5),
    text3: Color(0xFF8F8F80),
    hairline: Color(0x12F2F1E6), // text at 7 %
    primaryTint: Color(0x29B5C47C), // primary at 16 %
    onPrimaryTint: Color(0xFFD6E2A6),
    role: Color(0xFFC49A6C),
  );

  static const AppPalette light = AppPalette(
    bg: Color(0xFFF4F2E9),
    card: Color(0xFFFFFFFF),
    nested: Color(0xFFF0EEE3),
    control: Color(0xFFE6E4D6),
    raised: Color(0xFFDCDAC9),
    float: Color(0xDBF4F2E9), // bg at 86 %
    scrim: Color(0xE0F4F2E9), // bg at 88 %
    text: Color(0xFF1C1D16),
    text2: Color(0xFF56574B),
    text3: Color(0xFF6B6C5F),
    hairline: Color(0xFFE6E4D6),
    primaryTint: Color(0x1F4E6530), // primary at 12 %
    onPrimaryTint: Color(0xFF4E6530),
    role: Color(0xFF7E613C),
  );

  @override
  AppPalette copyWith({
    Color? bg,
    Color? card,
    Color? nested,
    Color? control,
    Color? raised,
    Color? float,
    Color? scrim,
    Color? text,
    Color? text2,
    Color? text3,
    Color? hairline,
    Color? primaryTint,
    Color? onPrimaryTint,
    Color? role,
  }) =>
      AppPalette(
        bg: bg ?? this.bg,
        card: card ?? this.card,
        nested: nested ?? this.nested,
        control: control ?? this.control,
        raised: raised ?? this.raised,
        float: float ?? this.float,
        scrim: scrim ?? this.scrim,
        text: text ?? this.text,
        text2: text2 ?? this.text2,
        text3: text3 ?? this.text3,
        hairline: hairline ?? this.hairline,
        primaryTint: primaryTint ?? this.primaryTint,
        onPrimaryTint: onPrimaryTint ?? this.onPrimaryTint,
        role: role ?? this.role,
      );

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      nested: Color.lerp(nested, other.nested, t)!,
      control: Color.lerp(control, other.control, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      float: Color.lerp(float, other.float, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      text: Color.lerp(text, other.text, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      primaryTint: Color.lerp(primaryTint, other.primaryTint, t)!,
      onPrimaryTint: Color.lerp(onPrimaryTint, other.onPrimaryTint, t)!,
      role: Color.lerp(role, other.role, t)!,
    );
  }
}

/// Convenience extension — read the semantic palette from any [BuildContext].
///
/// ```dart
/// context.palette.text3
/// ```
extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ??
      (Theme.of(this).brightness == Brightness.dark ? AppPalette.dark : AppPalette.light);
}

// ---------------------------------------------------------------------------
// Metric accent colors
// Dual-value (dark / light) via ThemeExtension so they're theme-aware.
// All eight share one oklch lightness per theme (0.76 dark, 0.52 light) so no
// metric reads "louder" than another; the light set is text-safe, and is used
// for fills, rings and bars too (docs/redesign/77-mobile-redesign-plan.md
// D-R0.3).
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

  /// "Better than last time" ↑ mark — always the protein green.
  Color get improvement => protein;

  /// Personal record 🏆 — always the carbs gold.
  Color get record => carbs;

  /// A signed "−" change (e.g. weight went down) — the weight blue.
  Color get decrease => weight;

  /// A signed "+" change (e.g. weight went up) — the calorie orange.
  Color get increase => calories;

  // Dark variants — oklch(0.76 0.11 h)
  static const AppMetricColors dark = AppMetricColors(
    calories: Color(0xFFEC9A66),
    protein: Color(0xFF93C98C),
    carbs: Color(0xFFE2BE62),
    fat: Color(0xFFA3A1DB),
    steps: Color(0xFFC593CC),
    weight: Color(0xFF98ADC0),
    water: Color(0xFF74B6D6),
    heart: Color(0xFFE07F76),
    positive: Color(0xFF93C98C),
    negative: Color(0xFFEC9A66),
  );

  // Light variants — the canvas hues and chromas at one shared oklch
  // lightness of 0.50. The canvas hexes (labelled 0.52) actually spread
  // over L 0.50–0.57, and calories / protein / carbs measured 4.1–4.3:1 on
  // their own 12 % chip tint — below AA. At 0.50 the worst chip is 4.82:1
  // and every colour is ≥ 5:1 as text on bg (contrast_test.dart;
  // docs/redesign/77-mobile-redesign-plan.md D-R0.3).
  static const AppMetricColors light = AppMetricColors(
    calories: Color(0xFF9D4602),
    protein: Color(0xFF34742F),
    carbs: Color(0xFF7F5D00),
    fat: Color(0xFF5A57A8),
    steps: Color(0xFF83488D),
    weight: Color(0xFF50667A),
    water: Color(0xFF1A6C8F),
    heart: Color(0xFFA73831),
    positive: Color(0xFF34742F),
    negative: Color(0xFF9D4602),
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
