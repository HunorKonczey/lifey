import 'package:flutter/material.dart';

/// Where the trainer view stops being a phone app
/// (docs/chat/41-trainer-mobile-v2-plan.md §8.2).
///
/// A trainer's screens are list → detail all day: clients and their data,
/// programs and their weeks. On a phone that is one thing at a time, and the
/// back button is the cost of every comparison. Past this width both fit, and
/// the same tap that pushed a screen selects a pane instead.
///
/// 900 dp rather than the usual 600: at 600 the list pane would take two
/// thirds of the width and the detail's own tab row would still not fit, which
/// is a worse tablet than a stretched phone.
const double trainerTwoPaneBreakpoint = 900;

/// The list pane's width. Wide enough for a client card with its compliance
/// badges, narrow enough to leave the detail the room it needs.
const double trainerListPaneWidth = 380;

/// How wide a single-column trainer screen lets its content grow. Cards
/// stretched across a 1280 dp tablet are unreadable long before they are
/// pretty.
const double trainerContentMaxWidth = 720;

/// True when there is room to show a list and what it points at side by side.
bool isTrainerTwoPane(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= trainerTwoPaneBreakpoint;

/// List on the left, whatever it points at on the right.
///
/// Both panes keep their own scroll position, and the divider is the only
/// chrome added — the [detail] is the same widget the phone pushes, told it is
/// embedded so it drops its back button.
class TrainerTwoPane extends StatelessWidget {
  const TrainerTwoPane({super.key, required this.list, required this.detail});

  final Widget list;
  final Widget detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: trainerListPaneWidth, child: list),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        Expanded(child: detail),
      ],
    );
  }
}

/// Keeps a single-column trainer screen readable on a wide display by
/// centering its content instead of stretching it.
class TrainerContentWidth extends StatelessWidget {
  const TrainerContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: trainerContentMaxWidth),
        child: child,
      ),
    );
  }
}
