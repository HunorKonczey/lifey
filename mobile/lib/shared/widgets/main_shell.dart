import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    // Nav bar = 84 dp fixed + safeBottom; sit 16 dp above it.
    final fabBottom = 84.0 + safeBottom + 16.0;

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
                final scheme = Theme.of(context).colorScheme;
                final fab = config.extended
                    ? FloatingActionButton.extended(
                        heroTag: null,
                        onPressed: config.onPressed,
                        icon: Icon(config.icon),
                        label: Text(config.label),
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(18)),
                        ),
                      )
                    : FloatingActionButton(
                        heroTag: null,
                        onPressed: config.onPressed,
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        child: Icon(config.icon),
                      );
                return Positioned(
                  right: 16,
                  bottom: fabBottom,
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
              bottom: fabBottom,
              child: const TrainerInviteCard(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: fabBottom,
              child: const UpcomingWorkoutCard(),
            ),
          ],
        ),
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
