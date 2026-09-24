import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'app_type.dart';

/// Centralized application theming — dark-first, warm olive identity.
///
/// Token source: docs/redesign/Lifey Design System.dc.html (design system v2),
/// mapped per docs/redesign/77-mobile-redesign-plan.md D-R0.2. Surface, text
/// and tint values live in [AppPalette]; this file maps them onto the
/// Material [ColorScheme] slots so stock widgets pick them up. Dark is the
/// hero theme; light is the same system, not an inversion.
class AppTheme {
  const AppTheme._();

  // ---------------------------------------------------------------------------
  // Dark
  // ---------------------------------------------------------------------------

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: _darkScheme,
        scaffoldBackgroundColor: AppPalette.dark.bg,
        fontFamily: _fontFamily,
        textTheme: _textTheme,
        extensions: const [AppMetricColors.dark, AppPalette.dark, AppElevation.dark],
        // Subtle, on-brand ripple — default is onSurface (~white) at 12%,
        // which looks harshly bright on near-black surfaces.
        splashColor: _darkPrimary.withValues(alpha: 0.10),
        highlightColor: _darkPrimary.withValues(alpha: 0.06),
      );

  static const Color _darkPrimary = Color(0xFFB5C47C);
  static const Color _lightPrimary = Color(0xFF4E6530);

  static ColorScheme get _darkScheme {
    const p = AppPalette.dark;
    return ColorScheme(
      brightness: Brightness.dark,
      // Primary — brand olive, reserved for controls (buttons, active tab,
      // selection); never a metric colour.
      primary: _darkPrimary,
      onPrimary: const Color(0xFF1A1F0A),
      // Opaque version of p.primaryTint — the header avatar fill on the canvas.
      primaryContainer: const Color(0xFF3A4228),
      onPrimaryContainer: p.onPrimaryTint,
      // Secondary — warm clay (also the trainer role mark, p.role)
      secondary: p.role,
      onSecondary: p.bg,
      secondaryContainer: const Color(0xFF2A2018),
      onSecondaryContainer: p.role,
      // Tertiary — forest green. Unchanged by the v2 palette; the trainer
      // shell stops using it as its accent in R6.
      tertiary: const Color(0xFF6E9A6A),
      onTertiary: p.bg,
      tertiaryContainer: const Color(0xFF1A2E1A),
      onTertiaryContainer: const Color(0xFF6E9A6A),
      // Error — keep Material standard for actual errors
      error: const Color(0xFFCF6679),
      onError: const Color(0xFF1C0008),
      errorContainer: const Color(0xFF8C1D2F),
      onErrorContainer: const Color(0xFFFFB3BF),
      // Surfaces — bg < card < nested < control < raised
      surface: p.bg,
      onSurface: p.text,
      onSurfaceVariant: p.text2,
      surfaceContainerLowest: p.bg,
      surfaceContainerLow: p.card,
      surfaceContainer: p.nested,
      surfaceContainerHigh: p.control,
      surfaceContainerHighest: p.raised,
      // Outline — component boundaries (outlined buttons, inputs) need to stay
      // visible, so this is stronger than the p.hairline divider.
      outline: const Color(0xFF45483B),
      outlineVariant: p.control,
      // Inverse
      inverseSurface: p.text,
      onInverseSurface: p.bg,
      inversePrimary: _lightPrimary,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
    );
  }

  // ---------------------------------------------------------------------------
  // Light
  // ---------------------------------------------------------------------------

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: _lightScheme,
        scaffoldBackgroundColor: AppPalette.light.bg,
        fontFamily: _fontFamily,
        textTheme: _textTheme,
        extensions: const [AppMetricColors.light, AppPalette.light, AppElevation.light],
        splashColor: _lightPrimary.withValues(alpha: 0.10),
        highlightColor: _lightPrimary.withValues(alpha: 0.06),
      );

  static ColorScheme get _lightScheme {
    const p = AppPalette.light;
    return ColorScheme(
      brightness: Brightness.light,
      // Primary — deep olive, 6.8:1 on white
      primary: _lightPrimary,
      onPrimary: Colors.white,
      // Opaque version of p.primaryTint (primary at 12 % on white).
      primaryContainer: const Color(0xFFEAECE6),
      onPrimaryContainer: p.onPrimaryTint,
      // Secondary — deep clay (also the trainer role mark, p.role).
      //
      // Was 0xFF8A6A42, which as text measured 4.42:1 on the old bg and
      // 4.15:1 on the old container — below WCAG AA's 4.5:1. Darkened ~3%
      // lightness at the same hue and saturation; same value as web's
      // `--secondary`, which was fixed for the same reason (the two products
      // share this palette).
      secondary: p.role,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFF4DFC8),
      onSecondaryContainer: const Color(0xFF2E1A08),
      // Tertiary — forest green. Darkened from 0xFF4A7A52 for the same reason
      // as secondary. Unchanged by the v2 palette.
      tertiary: const Color(0xFF44704C),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFCCE8D2),
      onTertiaryContainer: const Color(0xFF0A2E14),
      // Error
      error: const Color(0xFFBA1A2C),
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDADE),
      onErrorContainer: const Color(0xFF40000E),
      // Surfaces — white cards on a warm off-white bg; nesting gets darker.
      // Lowest stays white (the M3 light convention the existing call sites
      // were written against).
      surface: p.bg,
      onSurface: p.text,
      onSurfaceVariant: p.text2,
      surfaceContainerLowest: p.card,
      surfaceContainerLow: p.card,
      surfaceContainer: p.nested,
      surfaceContainerHigh: p.control,
      surfaceContainerHighest: p.raised,
      // Outline
      outline: const Color(0xFFCDCBBC),
      outlineVariant: p.hairline,
      // Inverse
      inverseSurface: p.text,
      onInverseSurface: p.bg,
      inversePrimary: _darkPrimary,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
    );
  }
}

// ---------------------------------------------------------------------------
// Typography
// ---------------------------------------------------------------------------

const String _fontFamily = AppType.fontFamily;

/// Shared TextTheme — applied to both dark and light ThemeData.
///
/// Scale: docs/redesign/Lifey Design System.dc.html › Tipográfia, mapped per
/// docs/redesign/77-mobile-redesign-plan.md D-R0.7. Design roles:
///   displayLarge   72/68 · 800 · −3 %   display-xl (weight log sheet)
///   displayMedium  48/48 · 800 · −2.5 % display (rest timer)
///   headlineMedium 30/36 · 800 · −2 %   headline (large page title, greeting)
///   titleLarge     20/26 · 700 · −1 %   title (card / sheet titles)
///   titleMedium    16/22 · 700          title-s (list-row title)
///   bodyMedium     15/22 · 500          body (default Text style)
///   bodySmall      13/18 · 500          body-s (metadata, footnotes)
///   labelSmall     12/16 · 700          label (caps + tracking via
///                                       AppType.sectionLabel, not here)
/// Derived, so no slot falls back to Material's 400-weight defaults:
///   displaySmall 36/40, headlineLarge 34/40, headlineSmall 24/30 (all 800),
///   titleSmall 14/20 · 700, bodyLarge 16/22 · 600 (Material's list-tile
///   title and input text), labelLarge 14/20 · 700 (buttons, nav pill),
///   labelMedium 13/16 · 600 (chips, tabs).
///
/// Display styles are tabular. Hero numbers at other sizes come from
/// AppType.number; they don't grow with dynamic type (AppType.noScale).
TextTheme get _textTheme => TextTheme(
      displayLarge: _ts(72, 68, FontWeight.w800, tracking: -0.03, tabular: true),
      displayMedium: _ts(48, 48, FontWeight.w800, tracking: -0.025, tabular: true),
      displaySmall: _ts(36, 40, FontWeight.w800, tracking: -0.025, tabular: true),
      headlineLarge: _ts(34, 40, FontWeight.w800, tracking: -0.02),
      headlineMedium: _ts(30, 36, FontWeight.w800, tracking: -0.02),
      headlineSmall: _ts(24, 30, FontWeight.w800, tracking: -0.02),
      titleLarge: _ts(20, 26, FontWeight.w700, tracking: -0.01),
      titleMedium: _ts(16, 22, FontWeight.w700),
      titleSmall: _ts(14, 20, FontWeight.w700),
      bodyLarge: _ts(16, 22, FontWeight.w600),
      bodyMedium: _ts(15, 22, FontWeight.w500),
      bodySmall: _ts(13, 18, FontWeight.w500),
      labelLarge: _ts(14, 20, FontWeight.w700),
      labelMedium: _ts(13, 16, FontWeight.w600),
      labelSmall: _ts(12, 16, FontWeight.w700),
    );

/// [lineHeight] in px (the canvas notation "size/line"), [tracking] as a
/// fraction of the size (the canvas's "−3 %").
TextStyle _ts(
  double size,
  double lineHeight,
  FontWeight weight, {
  double tracking = 0,
  bool tabular = false,
}) =>
    TextStyle(
      fontFamily: _fontFamily,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: tracking == 0 ? null : tracking * size,
      fontFeatures: tabular ? AppType.tabular : null,
    );
