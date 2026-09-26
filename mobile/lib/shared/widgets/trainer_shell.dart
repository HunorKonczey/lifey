import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../../features/trainer/application/trainer_view_preference.dart';
import '../../features/trainer/shared/trainer_layout.dart';
import '../../l10n/app_localizations.dart';
import 'ds/lifey_sheet.dart';
import 'adaptive_bottom_nav.dart';
import 'nav_collapse_controller.dart';
import 'trainer_nav_rail.dart';

/// The trainer's own shell, living beside [MainShell] rather than replacing
/// it (docs/chat/41-trainer-mobile-v2-plan.md §2.1, option 3).
///
/// The client's five branches are the client's workflow; a trainer's day is a
/// different one, and a trainer may well be a client too — so the two shells
/// coexist and the avatar menu moves between them.
///
/// Four branches, as the plan set out: Clients (T1), Calendar (T5),
/// Assignments (T4) and Programs (T6). Each appeared in the navigation on the
/// iteration that made it real — never as a half-finished tab — and the bar
/// itself stayed hidden while there was only one destination, because it
/// would have had nothing to say.
class TrainerShell extends ConsumerStatefulWidget {
  const TrainerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<TrainerShell> createState() => _TrainerShellState();
}

class _TrainerShellState extends ConsumerState<TrainerShell> {
  final _collapseController = NavCollapseController();

  @override
  void initState() {
    super.initState();
    // One card, once, on the first arrival — not a multi-step tour (frame A3).
    // The thing worth saying is where their own log went, because that is the
    // only question a trainer can be left with here.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowIntro());
  }

  Future<void> _maybeShowIntro() async {
    final preference = ref.read(trainerViewPreferenceProvider);
    if (await preference.hasSeenIntro()) return;
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    await showLifeySheet<void>(
      context: context,
      title: l10n.trainerIntroTitle,
      useRootNavigator: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.trainerIntroMessage,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: context.palette.text2),
          ),
          const SizedBox(height: AppSpacing.s24),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.trainerIntroDismissButton),
            ),
          ),
        ],
      ),
    );
    // Marked seen on dismissal either way: a card the trainer swiped away is a
    // card they have read, and showing it again would be nagging.
    await preference.setIntroSeen();
  }

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

    // One entry per registered branch, in the same order as the router's
    // `branches` list.
    final destinations = <AdaptiveNavDestination>[
      AdaptiveNavDestination(
        icon: Icons.group_outlined,
        selectedIcon: Icons.group,
        label: l10n.trainerClientsTitle,
      ),
      AdaptiveNavDestination(
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month,
        label: l10n.trainerCalendarTitle,
      ),
      AdaptiveNavDestination(
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment,
        label: l10n.trainerAssignmentsTitle,
      ),
      AdaptiveNavDestination(
        icon: Icons.calendar_view_week_outlined,
        selectedIcon: Icons.calendar_view_week,
        label: l10n.trainerProgramsTitle,
      ),
    ];

    // A tablet gets the rail beside the content instead of the floating bar
    // under it (canvas Lifey 6 › Trainer tablet).
    final rail = isTrainerTwoPane(context);
    final showNav = destinations.length >= 2;

    return NavCollapseScope(
      controller: _collapseController,
      child: Scaffold(
        extendBody: !rail,
        body: rail && showNav
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TrainerNavRail(
                    selectedIndex: widget.navigationShell.currentIndex,
                    onDestinationSelected: _onTap,
                    destinations: destinations,
                  ),
                  Expanded(child: widget.navigationShell),
                ],
              )
            : widget.navigationShell,
        bottomNavigationBar: rail || !showNav
            ? null
            : AdaptiveBottomNav(
                selectedIndex: widget.navigationShell.currentIndex,
                onDestinationSelected: _onTap,
                destinations: destinations,
              ),
      ),
    );
  }
}
