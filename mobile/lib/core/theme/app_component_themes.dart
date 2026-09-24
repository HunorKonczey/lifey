import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'app_type.dart';

/// Material component themes of design system v2 (docs/redesign/
/// 77-mobile-redesign-plan.md R0.8). Values are read from the canvases'
/// markup (Design System › Alapkomponensek, Lifey 5 login + logout dialog,
/// Lifey 2 add-food sheet); radii follow the 4-step scale even where a
/// canvas sample still uses an old value (buttons 16/18 → 14, FAB 20 → 22).
///
/// Applied on top of each theme in app_theme.dart, so the ~100 existing
/// buttons, ~70 text fields and every dialog pick them up without a call
/// site changing; a call site's own `styleFrom` still wins.
ThemeData withLifeyComponents(ThemeData base) {
  final p = base.extension<AppPalette>()!;
  final s = base.colorScheme;
  final t = base.textTheme;
  final dark = base.brightness == Brightness.dark;

  const controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)));
  final buttonText = t.labelLarge!.copyWith(fontSize: 15);

  // Secondary = surface-2 fill with a hairline ring ("Secondary" on the
  // canvas); used for OutlinedButton, so the ~17 existing outlined buttons
  // become the design's secondary button.
  final secondaryBorder = BorderSide(color: dark ? const Color(0x14F2F1E6) : const Color(0x1F1C1D16));

  return base.copyWith(
    // --- Buttons ------------------------------------------------------------
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
        shape: controlShape,
        textStyle: buttonText,
        // Pressed = one surface step lighter, not a ripple splash.
        splashFactory: NoSplash.splashFactory,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed) ? Colors.white.withValues(alpha: dark ? 0.12 : 0.16) : null,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
        shape: controlShape,
        textStyle: buttonText,
        foregroundColor: p.text,
        backgroundColor: p.nested,
        side: secondaryBorder,
        splashFactory: NoSplash.splashFactory,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
        shape: controlShape,
        textStyle: buttonText,
        foregroundColor: s.primary,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: s.primary,
      foregroundColor: s.onPrimary,
      extendedTextStyle: t.labelLarge!.copyWith(fontSize: 16),
      extendedPadding: const EdgeInsets.only(left: 18, right: 22),
      extendedIconLabelSpacing: AppSpacing.s8,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.card))),
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      sizeConstraints: const BoxConstraints.tightFor(width: 56, height: 56),
      extendedSizeConstraints: const BoxConstraints(minHeight: 56, minWidth: 56),
    ),

    // --- Chips (filter / choice) ------------------------------------------
    // Canvas "CHIP · szűrő, választó": 40 tall, selected = solid brand olive
    // with a check, unselected = surface-2 with a hairline ring.
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: WidgetStateBorderSide.resolveWith(
        (states) => states.contains(WidgetState.selected) ? BorderSide.none : secondaryBorder,
      ),
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? s.primary : p.nested,
      ),
      labelStyle: WidgetStateTextStyle.resolveWith(
        (states) => t.labelMedium!.copyWith(
          fontSize: 14,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
          color: states.contains(WidgetState.selected) ? s.onPrimary : p.text,
        ),
      ),
      checkmarkColor: s.onPrimary,
      iconTheme: IconThemeData(color: p.text2, size: 18),
      showCheckmark: true,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
      labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
    ),

    // --- Inputs -------------------------------------------------------------
    // Default = a field inside a card or sheet ("Search foods"): surface-3
    // fill, no ring, 14 radius, ≥ 52 tall; focus draws a 1.5 px olive ring
    // (the login canvas). Fields sitting straight on the page (login) pass
    // `fillColor: palette.card` plus a hairline — done in R5.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.control,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 16),
      constraints: const BoxConstraints(minHeight: 52),
      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)), borderSide: BorderSide.none),
      enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.control)),
        borderSide: BorderSide(color: s.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.control)),
        borderSide: BorderSide(color: s.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.control)),
        borderSide: BorderSide(color: s.error, width: 1.5),
      ),
      hintStyle: t.bodyMedium!.copyWith(color: p.text2),
      labelStyle: t.labelMedium!.copyWith(color: p.text2),
      floatingLabelStyle: t.labelMedium!.copyWith(color: p.text2),
      helperStyle: t.bodySmall!.copyWith(color: p.text3),
      prefixIconColor: p.text2,
      suffixIconColor: p.text2,
    ),

    // --- Dialogs, menus, snackbars, dividers --------------------------------
    // Canvas logout dialog: radius 30, padding 24, title 22/800, body 15/500
    // text-2; the fill sits between surface-2 and surface-3 in dark (#2A2D22
    // ≈ control), white in light.
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? p.control : p.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.hero))),
      titleTextStyle: t.headlineSmall!.copyWith(fontSize: 22, height: 1.25, color: p.text),
      contentTextStyle: t.bodyMedium!.copyWith(height: 1.5, color: p.text2),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.s24, 0, AppSpacing.s24, AppSpacing.s24),
      barrierColor: Colors.black.withValues(alpha: 0.6),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: dark ? p.control : p.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.control))),
      textStyle: t.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: p.text),
      elevation: 8,
    ),
    // Plain SnackBars (not AppSnackbar) — an inverse, floating card.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppPalette.dark.control,
      contentTextStyle: t.bodyMedium!.copyWith(fontWeight: FontWeight.w600, color: AppPalette.dark.text),
      actionTextColor: AppMetricColors.dark.positive,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.card))),
      insetPadding: const EdgeInsets.fromLTRB(AppSpacing.s16, 0, AppSpacing.s16, AppSpacing.s8),
    ),
    dividerTheme: DividerThemeData(color: p.hairline, thickness: 1, space: 1),
    // Generic (non-metric) progress: brand olive on a surface-3 track. Data
    // progress uses ProgressRing / MetricBar in the metric colour (R0.9).
    progressIndicatorTheme: ProgressIndicatorThemeData(color: s.primary, linearTrackColor: p.control, circularTrackColor: p.control),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: s.primary,
      selectionColor: s.primary.withValues(alpha: 0.3),
      selectionHandleColor: s.primary,
    ),
  );
}

/// The full-width 56 px primary call to action ("Apply these goals",
/// "Sign in"). Use as `FilledButton(style: lifeyLargeButtonStyle, …)`.
final ButtonStyle lifeyLargeButtonStyle = FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(56),
  textStyle: const TextStyle(fontFamily: AppType.fontFamily, fontSize: 16, fontWeight: FontWeight.w700),
);
