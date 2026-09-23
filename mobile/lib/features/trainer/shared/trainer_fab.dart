import 'package:flutter/material.dart';

import '../../../core/ads/nav_reserved_space.dart';

/// Places a trainer screen's FAB above `AdaptiveBottomNav`.
///
/// The nav is a *floating* pill the shell draws with `extendBody: true`, so a
/// screen's own `Scaffold` knows nothing about it: its FAB would sit at the
/// screen's bottom edge, on top of the nav. These two helpers put it where the
/// client shell puts its own FAB — `navSlotHeight` above the nav's slot, plus
/// [fabGap] (see `core/ads/nav_reserved_space.dart`, the same math
/// `main_shell.dart` uses).
///
/// Which one to use depends on how the screen draws the FAB:
///
/// * [TrainerFabPadding] wraps a `Scaffold.floatingActionButton`, whose own
///   layout already lifts it clear of the safe area.
/// * [trainerFabBottom] is for a FAB placed by hand in a `Stack`, where the
///   safe area still has to be counted — unless the `Stack` is inside a
///   `SafeArea`, in which case `MediaQuery.paddingOf` is already zero there
///   and the same call stays correct.
class TrainerFabPadding extends StatelessWidget {
  const TrainerFabPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: navSlotHeight),
      child: child,
    );
  }
}

/// Distance from the bottom edge for a hand-placed trainer FAB.
double trainerFabBottom(BuildContext context) =>
    fabBottom(MediaQuery.paddingOf(context).bottom);
