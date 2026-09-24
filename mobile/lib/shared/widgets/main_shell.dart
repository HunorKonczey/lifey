import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/banner_ad_slot.dart';
import '../../core/ads/nav_reserved_space.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/trainer_invite/presentation/trainer_invite_card.dart';
import '../../features/workouts/presentation/widgets/upcoming_workout_card.dart';
import '../../l10n/app_localizations.dart';
import 'adaptive_bottom_nav.dart';
import 'nav_collapse_controller.dart';
import 'shell_fab.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final _collapseController = NavCollapseController();

  @override
  void dispose() {
    _collapseController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    _collapseController.expand();
    ref.read(activeShellTabProvider.notifier).set(index);
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // Above the nav, and above the active tab's banner too if one is
    // showing (`67` §5.2: "Never over a FAB") — see core/ads/nav_reserved_space.dart.
    final activeTab = ref.watch(activeShellTabProvider);
    final bannerHeight = ref.watch(bannerAdSlotHeightProvider(activeTab));
    final fabBottomValue = fabBottom(safeBottom, bannerHeight: bannerHeight);

    return NavCollapseScope(
      controller: _collapseController,
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            widget.navigationShell,
            Consumer(
              builder: (context, ref, _) {
                final config = ref.watch(shellFabProvider);
                final currentTab = widget.navigationShell.currentIndex;
                if (config == null || config.tabIndex != currentTab) {
                  return const SizedBox.shrink();
                }
                // Shape, colours and size come from the v2 FAB theme
                // (app_component_themes.dart); the olive glow is the canvas's
                // "0 12 24 −8 primary @ 35 %" (docs/redesign/77 R0.11).
                final primary = Theme.of(context).colorScheme.primary;
                final fab = DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(AppRadius.card)),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.35),
                        offset: const Offset(0, 12),
                        blurRadius: 24,
                        spreadRadius: -8,
                      ),
                    ],
                  ),
                  child: config.extended
                      ? FloatingActionButton.extended(
                          heroTag: null,
                          onPressed: config.onPressed,
                          icon: Icon(config.icon, size: 24),
                          label: Text(config.label),
                        )
                      : FloatingActionButton(
                          heroTag: null,
                          onPressed: config.onPressed,
                          child: Icon(config.icon),
                        ),
                );
                return Positioned(
                  right: AppSpacing.screen,
                  bottom: fabBottomValue,
                  // GestureDetector sits *above* the FAB's own InkWell in the
                  // gesture arena — a plain tap still reaches
                  // `config.onPressed` untouched, a long-press (when the
                  // screen sets one, e.g. Workouts' quick-start sheet,
                  // docs/cardio/59-cardio-implementation-plan.md C2.7) is
                  // claimed here instead. `FloatingActionButton` has no
                  // `onLongPress` of its own, so wrapping is the only way to
                  // add one without forking the widget.
                  child: config.onLongPress == null
                      ? fab
                      : GestureDetector(onLongPress: config.onLongPress, child: fab),
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: fabBottomValue,
              child: const TrainerInviteCard(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: fabBottomValue,
              child: const UpcomingWorkoutCard(),
            ),
          ],
        ),
        bottomNavigationBar: AdaptiveBottomNav(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: _onTap,
          destinations: [
            AdaptiveNavDestination(
              icon: Icons.space_dashboard_outlined,
              selectedIcon: Icons.space_dashboard_rounded,
              label: l10n.dashboardTabLabel,
            ),
            AdaptiveNavDestination(
              icon: Icons.restaurant_outlined,
              selectedIcon: Icons.restaurant_rounded,
              label: l10n.nutritionTitle,
            ),
            AdaptiveNavDestination(
              icon: Icons.fitness_center_outlined,
              selectedIcon: Icons.fitness_center_rounded,
              label: l10n.workoutsTitle,
            ),
            AdaptiveNavDestination(
              icon: Icons.monitor_weight_outlined,
              selectedIcon: Icons.monitor_weight_rounded,
              label: l10n.weightTitle,
            ),
            AdaptiveNavDestination(
              icon: Icons.bar_chart_outlined,
              selectedIcon: Icons.bar_chart_rounded,
              label: l10n.statisticsTitle,
            ),
          ],
        ),
      ),
    );
  }
}
