import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Centralized application theming — dark-first, brown-green identity.
///
/// Token source: docs/design/design-handoff/.../Lifey Redesign.dc.html
/// Dark is the hero theme; light uses the same semantic tokens on a warm
/// off-white base.
class AppTheme {
  const AppTheme._();

  // ---------------------------------------------------------------------------
  // Dark
  // ---------------------------------------------------------------------------

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: _darkScheme,
        scaffoldBackgroundColor: _dark.bg,
        fontFamily: _fontFamily,
        textTheme: _textTheme,
        extensions: const [AppMetricColors.dark],
      );

  static const _DarkColors _dark = _DarkColors();

  static ColorScheme get _darkScheme => ColorScheme(
        brightness: Brightness.dark,
        // Primary — moss-olive green
        primary: _dark.primary,
        onPrimary: _dark.bg,
        primaryContainer: _dark.container,
        onPrimaryContainer: _dark.primary,
        // Secondary — warm brown
        secondary: _dark.secondary,
        onSecondary: _dark.bg,
        secondaryContainer: const Color(0xFF2A2018),
        onSecondaryContainer: _dark.secondary,
        // Tertiary — forest green
        tertiary: _dark.tertiary,
        onTertiary: _dark.bg,
        tertiaryContainer: const Color(0xFF1A2E1A),
        onTertiaryContainer: _dark.tertiary,
        // Error — keep Material standard for actual errors
        error: const Color(0xFFCF6679),
        onError: const Color(0xFF1C0008),
        errorContainer: const Color(0xFF8C1D2F),
        onErrorContainer: const Color(0xFFFFB3BF),
        // Surfaces — stepped warm-dark layers
        surface: _dark.surface,
        onSurface: _dark.onSurface,
        onSurfaceVariant: _dark.onSurfaceVariant,
        surfaceContainerLowest: _dark.bg,
        surfaceContainerLow: _dark.surface,
        surfaceContainer: _dark.container,
        surfaceContainerHigh: _dark.high,
        surfaceContainerHighest: _dark.highest,
        // Outline
        outline: const Color(0xFF3C3E32),
        outlineVariant: _dark.high,
        // Inverse
        inverseSurface: _dark.onSurface,
        onInverseSurface: _dark.bg,
        inversePrimary: const Color(0xFF586E38),
        shadow: const Color(0xFF000000),
        scrim: const Color(0xFF000000),
      );

  // ---------------------------------------------------------------------------
  // Light
  // ---------------------------------------------------------------------------

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: _lightScheme,
        scaffoldBackgroundColor: _light.bg,
        fontFamily: _fontFamily,
        textTheme: _textTheme,
        extensions: const [AppMetricColors.light],
      );

  static const _LightColors _light = _LightColors();

  static ColorScheme get _lightScheme => ColorScheme(
        brightness: Brightness.light,
        // Primary — deeper olive for light contrast
        primary: _light.primary,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFDDEEBB),
        onPrimaryContainer: const Color(0xFF1A2E0A),
        // Secondary — deep brown
        secondary: _light.secondary,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFF4DFC8),
        onSecondaryContainer: const Color(0xFF2E1A08),
        // Tertiary — forest green
        tertiary: _light.tertiary,
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFFCCE8D2),
        onTertiaryContainer: const Color(0xFF0A2E14),
        // Error
        error: const Color(0xFFBA1A2C),
        onError: Colors.white,
        errorContainer: const Color(0xFFFFDADE),
        onErrorContainer: const Color(0xFF40000E),
        // Surfaces
        surface: _light.surface,
        onSurface: _light.onSurface,
        onSurfaceVariant: _light.onSurfaceVariant,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF8F7EE),
        surfaceContainer: _light.bg,
        surfaceContainerHigh: _light.container,
        surfaceContainerHighest: const Color(0xFFE6E5D8),
        // Outline
        outline: _light.outline,
        outlineVariant: const Color(0xFFE6E5DC),
        // Inverse
        inverseSurface: _light.onSurface,
        onInverseSurface: _light.bg,
        inversePrimary: const Color(0xFF9DAE6B),
        shadow: const Color(0xFF000000),
        scrim: const Color(0xFF000000),
      );
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

// ---------------------------------------------------------------------------
// Color value holders — single source of truth per theme
// ---------------------------------------------------------------------------

final class _DarkColors {
  const _DarkColors();

  /// Near-black warm bg — scaffold background, deepest surface
  Color get bg => const Color(0xFF161611);

  /// Main surface (cards, list tiles sit on this)
  Color get surface => const Color(0xFF1C1E16);

  /// Container surface (elevated cards, stat cards)
  Color get container => const Color(0xFF22241B);

  /// High container (nav bar, floating bars)
  Color get high => const Color(0xFF2A2C20);

  /// Highest container (chips, segmented selected bg)
  Color get highest => const Color(0xFF32342A);

  /// Moss-olive primary accent
  Color get primary => const Color(0xFF9DAE6B);

  /// Warm brown secondary
  Color get secondary => const Color(0xFFC49A6C);

  /// Forest green tertiary
  Color get tertiary => const Color(0xFF6E9A6A);

  /// Primary text on dark surfaces
  Color get onSurface => const Color(0xFFF1F0E4);

  /// Muted / secondary text
  Color get onSurfaceVariant => const Color(0xFFA8A899);
}

final class _LightColors {
  const _LightColors();

  /// Warm off-white scaffold background
  Color get bg => const Color(0xFFF3F2E8);

  /// Pure white surface for cards
  Color get surface => const Color(0xFFFFFFFF);

  /// Container (elevated groups)
  Color get container => const Color(0xFFECEBDE);

  /// Deeper olive for light-mode primary (contrast on white)
  Color get primary => const Color(0xFF586E38);

  /// Deep warm brown
  Color get secondary => const Color(0xFF8A6A42);

  /// Forest green
  Color get tertiary => const Color(0xFF4A7A52);

  /// Near-black primary text
  Color get onSurface => const Color(0xFF1E1F18);

  /// Muted secondary text
  Color get onSurfaceVariant => const Color(0xFF5C5C50);

  /// Subtle borders
  Color get outline => const Color(0xFFCDCBBC);
}
