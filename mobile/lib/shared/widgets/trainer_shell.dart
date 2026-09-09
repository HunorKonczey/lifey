import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import 'adaptive_bottom_nav.dart';
import 'nav_collapse_controller.dart';

/// The trainer's own shell, living beside [MainShell] rather than replacing
/// it (docs/chat/41-trainer-mobile-v2-plan.md §2.1, option 3).
///
/// The client's five branches are the client's workflow; a trainer's day is a
/// different one, and a trainer may well be a client too — so the two shells
/// coexist and the avatar menu moves between them.
///
/// The plan's target is four branches (Clients · Calendar · Assignments ·
/// Programs). T1 ships the first one only, and the rule is that a branch
/// appears in the navigation on the iteration that makes it real — never as a
/// half-finished tab. Until there are at least two, the bar itself would say
/// nothing, so it stays hidden.
class TrainerShell extends ConsumerStatefulWidget {
  const TrainerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<TrainerShell> createState() => _TrainerShellState();
}

class _TrainerShellState extends ConsumerState<TrainerShell> {
  final _collapseController = NavCollapseController();

  @override
  void dispose() {
    _collapseController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    _collapseController.expand();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    // One entry per registered branch, in the same order as the router's
    // `branches` list — T2 (calendar), T4 (assignments) and T6 (programs)
    // each add one here and one there.
    final destinations = <AdaptiveNavDestination>[
      AdaptiveNavDestination(
        icon: Icons.group_outlined,
        selectedIcon: Icons.group,
        label: l10n.trainerClientsTitle,
      ),
    ];

    return NavCollapseScope(
      controller: _collapseController,
      child: Scaffold(
        extendBody: true,
        body: widget.navigationShell,
        bottomNavigationBar: destinations.length < 2
            ? null
            : AdaptiveBottomNav(
                selectedIndex: widget.navigationShell.currentIndex,
                onDestinationSelected: _onTap,
                destinations: destinations,
                // The one visual difference from the client shell — same
                // system, different accent (frame A1).
                accentColor: scheme.tertiary,
              ),
      ),
    );
  }
}
