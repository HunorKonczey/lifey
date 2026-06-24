import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
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
// AdaptiveBottomNav
// ---------------------------------------------------------------------------
// Floating, scroll-reactive bottom navigation bar.
//
// Expanded state : full-width rect between 14 px side margins, icons + labels.
// Collapsed state: centered stadium pill, icons only.
//
// Animation mirrors Lifey Nav Prototype.dc.html:
//   expanded fades + slides down when collapsing;
//   pill fades + scales up from .85 → 1.0 when collapsing.
//
// Place in Scaffold.bottomNavigationBar with extendBody: true so the list
// content scrolls freely underneath. Safe-area is handled internally.
// ---------------------------------------------------------------------------

class AdaptiveBottomNav extends StatelessWidget {
  const AdaptiveBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveNavDestination> destinations;

  static const double _navHeight = 58.0;
  static const double _bottomGap = 26.0;

  @override
  Widget build(BuildContext context) {
    final collapsed = NavCollapseScope.collapsedOf(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: _navHeight + _bottomGap + safeBottom,
      child: Padding(
        padding: EdgeInsets.only(bottom: _bottomGap + safeBottom),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Expanded bar ─────────────────────────────────────────────────
            Positioned(
              left: 14,
              right: 14,
              top: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: collapsed ? 0.0 : 1.0,
                duration: AppDuration.collapse,
                curve: AppCurve.collapse,
                child: AnimatedSlide(
                  offset: collapsed ? const Offset(0, 0.22) : Offset.zero,
                  duration: AppDuration.collapse,
                  curve: AppCurve.collapse,
                  child: IgnorePointer(
                    ignoring: collapsed,
                    child: _ExpandedBar(
                      destinations: destinations,
                      selectedIndex: selectedIndex,
                      onTap: onDestinationSelected,
                      scheme: scheme,
                    ),
                  ),
                ),
              ),
            ),

            // ── Collapsed pill ────────────────────────────────────────────────
            AnimatedOpacity(
              opacity: collapsed ? 1.0 : 0.0,
              duration: AppDuration.collapse,
              curve: AppCurve.collapse,
              child: AnimatedScale(
                scale: collapsed ? 1.0 : 0.85,
                duration: AppDuration.collapse,
                curve: AppCurve.collapse,
                child: IgnorePointer(
                  ignoring: !collapsed,
                  child: _CollapsedPill(
                    destinations: destinations,
                    selectedIndex: selectedIndex,
                    onTap: onDestinationSelected,
                    scheme: scheme,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expanded bar
// ---------------------------------------------------------------------------

class _ExpandedBar extends StatelessWidget {
  const _ExpandedBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
    required this.scheme,
  });

  final List<AdaptiveNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.nav),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (int i = 0; i < destinations.length; i++)
              _NavItem(
                destination: destinations[i],
                selected: i == selectedIndex,
                onTap: () => onTap(i),
                scheme: scheme,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collapsed pill
// ---------------------------------------------------------------------------

class _CollapsedPill extends StatelessWidget {
  const _CollapsedPill({
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
    required this.scheme,
  });

  final List<AdaptiveNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: AppRadius.pill,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < destinations.length; i++) ...[
              if (i > 0) const SizedBox(width: 22),
              GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  i == selectedIndex
                      ? destinations[i].selectedIcon
                      : destinations[i].icon,
                  size: 25,
                  color: i == selectedIndex
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single nav item (expanded bar)
// ---------------------------------------------------------------------------

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.scheme,
  });

  final AdaptiveNavDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? destination.selectedIcon : destination.icon,
              size: 25,
              color: color,
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: color,
                // height: 1.0 removes the font's implicit leading so the text
                // box is exactly 10 px — keeps the Column within the 58 px bar.
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
