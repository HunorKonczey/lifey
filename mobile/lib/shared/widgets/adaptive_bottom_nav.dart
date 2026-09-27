import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/ads/nav_reserved_space.dart';
import '../../core/theme/app_tokens.dart';
import 'ds/card_edge_painter.dart';
import 'nav_collapse_controller.dart';

// ---------------------------------------------------------------------------
// Public destination descriptor
// ---------------------------------------------------------------------------

class AdaptiveNavDestination {
  const AdaptiveNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

// ---------------------------------------------------------------------------
// AdaptiveBottomNav — design system v2
// ---------------------------------------------------------------------------
// Floating bottom navigation (canvas "ALSÓ NAVIGÁCIÓ · aktív fül kinyílik";
// docs/redesign/77-mobile-redesign-plan.md R0.11):
//
// - A 68 px bar, radius 30, 16 px from the screen edges, on the translucent
//   `float` layer with a 24 px backdrop blur, the e3 shadow and a top light
//   edge in dark.
// - **Only the active tab shows its label**, inside a 48 px brand-olive pill
//   (icon 22 filled + 14/700 label); the others are 48 × 48 outlined icons in
//   the secondary text colour. So the longest Hungarian names ("Áttekintés",
//   "Statisztika") fit, and every target stays 48 dp. Screen readers get
//   every tab's name and its selected state regardless.
// - Scrolling down flattens the bar to 56 px (no separate collapsed pill
//   any more); scrolling up or switching tabs restores it.
// - A soft bg gradient behind the bar fades content scrolling under it.
//
// The slot it reserves (68 + 16 gap = 84, plus the safe area) is
// `navSlotHeight`, which the banner-ad and FAB placement math reads — the v1
// bar reserved the same 84, so none of that moved.
//
// Place in Scaffold.bottomNavigationBar with extendBody: true.
// ---------------------------------------------------------------------------

class AdaptiveBottomNav extends StatelessWidget {
  const AdaptiveBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.accentColor,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveNavDestination> destinations;

  /// Colour of the active pill. Defaults to `colorScheme.primary`; the
  /// trainer shell still passes `tertiary` until R6 folds it into the client
  /// family.
  final Color? accentColor;

  static const double barHeight = 68;
  static const double collapsedHeight = 56;
  static const double bottomGap = navSlotHeight - barHeight;
  static const double sideMargin = 16;

  @override
  Widget build(BuildContext context) {
    final collapsed = NavCollapseScope.collapsedOf(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;
    final p = context.palette;
    final e = context.elevation;
    final accent = accentColor ?? scheme.primary;
    final onAccent = accent == scheme.primary
        ? scheme.onPrimary
        : (ThemeData.estimateBrightnessForColor(accent) == Brightness.dark ? Colors.white : p.bg);
    final duration = AppMotion.of(context, AppMotion.page);
    const radius = BorderRadius.all(Radius.circular(AppRadius.hero));

    return SizedBox(
      height: navSlotHeight + safeBottom,
      child: Stack(
        children: [
          // Fade for content scrolling under the bar (canvas: bg 0 → 95 %).
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [p.bg.withValues(alpha: 0), p.bg.withValues(alpha: 0.95)],
                    stops: const [0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: sideMargin,
            right: sideMargin,
            bottom: bottomGap + safeBottom,
            child: AnimatedContainer(
              duration: duration,
              curve: AppMotion.standard,
              height: collapsed ? collapsedHeight : barHeight,
              decoration: BoxDecoration(borderRadius: radius, boxShadow: e.e3),
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: AppElevation.floatBlur, sigmaY: AppElevation.floatBlur),
                  child: CustomPaint(
                    foregroundPainter: CardEdgePainter(color: e.floatEdge, borderRadius: radius),
                    child: ColoredBox(
                      color: p.float,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (var i = 0; i < destinations.length; i++)
                              _NavItem(
                                destination: destinations[i],
                                selected: i == selectedIndex,
                                onTap: () => onDestinationSelected(i),
                                accent: accent,
                                onAccent: onAccent,
                                duration: duration,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One destination: a 48 × 48 icon, or — when active — a 48 px pill with the
/// icon and label that grows open.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.accent,
    required this.onAccent,
    required this.duration,
  });

  final AdaptiveNavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final Color onAccent;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final label = selected
        ? Padding(
            padding: const EdgeInsets.only(left: AppSpacing.s8),
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  destination.label,
                  maxLines: 1,
                  style: t.labelLarge!.copyWith(color: onAccent, height: 1),
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
    final item = AnimatedContainer(
      duration: duration,
      curve: AppMotion.standard,
      height: 48,
      constraints: const BoxConstraints(minWidth: 48),
      padding: EdgeInsets.only(left: selected ? 14 : 12, right: selected ? 16 : 12),
      decoration: BoxDecoration(
        color: selected ? accent : accent.withValues(alpha: 0),
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? destination.selectedIcon : destination.icon,
            size: selected ? 22 : 24,
            color: selected ? onAccent : p.text2,
          ),
          // The label only exists on the active tab; it grows in with the
          // pill. The visible text is excluded from semantics — the item's
          // own label covers every tab.
          Flexible(
            // AnimatedSize with a zero duration (reduced motion) trips a
            // layout assertion — skip it when there is nothing to animate.
            child: duration == Duration.zero
                ? label
                : AnimatedSize(
                    duration: duration,
                    curve: AppMotion.standard,
                    alignment: Alignment.centerLeft,
                    child: label,
                  ),
          ),
        ],
      ),
    );

    // The active pill takes what room it needs; icons keep their 48.
    return Flexible(
      flex: selected ? 1 : 0,
      fit: FlexFit.loose,
      child: Semantics(
        label: destination.label,
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: item,
        ),
      ),
    );
  }
}
