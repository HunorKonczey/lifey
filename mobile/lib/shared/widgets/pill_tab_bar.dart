import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Pill-shaped segmented tab bar — the nutrition canvas's "Meals · Recipes ·
/// Foods · Macros" (design system v2; docs/redesign/77-mobile-redesign-plan.md
/// R0.8).
///
/// A card-coloured pill track with a hairline ring and 4 px padding; the
/// active tab is a surface-3 pill with a small shadow and 700-weight text,
/// the others 600 in the secondary text colour. (The v1 bar filled the active
/// tab with brand olive; v2 keeps olive for actions, not for "where am I".)
///
/// The [tabs] list is passed straight to [TabBar.tabs] — use [Tab(text: …)]
/// for text-only tabs. 46 tall in all: 38 pills in a 4 px track.
class PillTabBar extends StatelessWidget {
  const PillTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.horizontalMargin = legacyMargin,
  });

  final TabController controller;
  final List<Widget> tabs;

  /// Side margin. Defaults to the v1 12 px the unmigrated screens' content
  /// still uses, so the bar lines up with the cards under it; a screen
  /// passes [AppSpacing.screen] (20, the design's margin) in the iteration
  /// that moves its content to 20 too (R0 emulator review: a 20 px bar over
  /// 12 px cards looked misaligned).
  final double horizontalMargin;

  static const double legacyMargin = 12;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: AppSpacing.s8),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(color: p.card, borderRadius: AppRadius.pill),
        // Foreground, like the canvas's inset ring — a real border would eat
        // 2 px of the 38 px pills.
        foregroundDecoration: BoxDecoration(
          borderRadius: AppRadius.pill,
          border: Border.all(color: context.elevation.border),
        ),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
            color: p.control,
            borderRadius: AppRadius.pill,
            boxShadow: dark
                ? const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 8)]
                : context.elevation.e1,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          labelColor: p.text,
          unselectedLabelColor: p.text2,
          labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          labelStyle: t.labelLarge!.copyWith(fontWeight: FontWeight.w700, height: 1),
          unselectedLabelStyle: t.labelLarge!.copyWith(fontWeight: FontWeight.w600, height: 1),
          tabs: [for (final tab in tabs) _fitted(tab)],
        ),
      ),
    );
  }

  /// The tabs share the bar equally; a text label that doesn't fit its
  /// share (Hungarian at 130 % — "Étkezések", "Receptek") shrinks instead of
  /// being clipped mid-word. Other tab widgets pass through unchanged.
  static Widget _fitted(Widget tab) {
    if (tab is! Tab || tab.text == null || tab.icon != null) return tab;
    return Tab(
      key: tab.key,
      height: tab.height,
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(tab.text!, maxLines: 1, softWrap: false)),
    );
  }
}
