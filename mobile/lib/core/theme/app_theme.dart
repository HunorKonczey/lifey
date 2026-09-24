import 'package:flutter/material.dart';

import 'app_tokens.dart';

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
        extensions: const [AppMetricColors.dark, AppPalette.dark],
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
        extensions: const [AppMetricColors.light, AppPalette.light],
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

const String _fontFamily = 'PlusJakartaSans';

/// Shared TextTheme — applied to both dark and light ThemeData.
///
/// Scale (mockup source: Lifey Redesign.dc.html › Type block):
///   displayLarge  34 / 800  — hero metric numbers (dashboard stat values)
///   headlineMedium 26 / 700  — screen titles
///   titleLarge    20 / 700  — section headers, card titles
///   bodyMedium    15 / 500  — default body / list subtitles
///   labelMedium   13 / 600  — section labels, chips, tab text
///
/// Tabular numerals are set on display-scale styles so metric values
/// (calories, weight, steps…) align cleanly in cards.
TextTheme get _textTheme => TextTheme(
      // 34 / 800 — biggest metric values (e.g. "1,780 kcal" hero card)
      displayLarge: _ts(34, FontWeight.w800, tabular: true),
      // 26 / 700 — screen titles in app bars
      headlineMedium: _ts(26, FontWeight.w700),
      // 20 / 700 — section titles, card headings
      titleLarge: _ts(20, FontWeight.w700),
      // 15 / 500 — body text, list subtitles
      bodyMedium: _ts(15, FontWeight.w500),
      // 14 / 600 — slightly prominent body (list tile titles)
      bodyLarge: _ts(14, FontWeight.w600),
      // 13 / 600 — labels, section headers, tab bar
      labelMedium: _ts(13, FontWeight.w600),
      // 11 / 700 — uppercase section labels (ALL CAPS tracked)
      labelSmall: _ts(11, FontWeight.w700),
    );

TextStyle _ts(double size, FontWeight weight, {bool tabular = false}) =>
    TextStyle(
      fontFamily: _fontFamily,
      fontSize: size,
      fontWeight: weight,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
