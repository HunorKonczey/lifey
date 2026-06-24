import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import 'adaptive_bottom_nav.dart';
import 'nav_collapse_controller.dart';

/// App shell hosting the floating bottom navigation.
///
/// Owns the [NavCollapseController] and wraps the whole subtree in
/// [NavCollapseScope] so every screen and the nav bar can read and drive the
/// collapse state without direct coupling.
///
/// [extendBody: true] lets the nav bar float over the body. Each screen adds
/// its own top/bottom clearance via the floating [AdaptiveAppBar] + padding.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _collapseController = NavCollapseController();

  @override
  void dispose() {
    _collapseController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    // Switching tabs always snaps the bars back to expanded — the new tab
    // starts at the top of its scroll position.
    _collapseController.expand();
    widget.navigationShell.goBranch(
      index,
      // Tapping the active tab again returns it to its initial route.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return NavCollapseScope(
      controller: _collapseController,
      child: Scaffold(
        // extendBody lets the body paint behind the floating bottom nav so
        // scroll content slides under it naturally.
        extendBody: true,
        body: widget.navigationShell,
        bottomNavigationBar: AdaptiveBottomNav(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: _onTap,
          destinations: [
            AdaptiveNavDestination(
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard,
              label: l10n.dashboardTabLabel,
            ),
            AdaptiveNavDestination(
              icon: Icons.restaurant_outlined,
              selectedIcon: Icons.restaurant,
              label: l10n.nutritionTitle,
            ),
            AdaptiveNavDestination(
              icon: Icons.fitness_center_outlined,
              selectedIcon: Icons.fitness_center,
              label: l10n.workoutsTitle,
            ),
            AdaptiveNavDestination(
              icon: Icons.monitor_weight_outlined,
              selectedIcon: Icons.monitor_weight,
              label: l10n.weightTitle,
            ),
            AdaptiveNavDestination(
              icon: Icons.bar_chart_outlined,
              selectedIcon: Icons.bar_chart,
              label: l10n.statisticsTitle,
            ),
          ],
        ),
      ),
    );
  }
}
