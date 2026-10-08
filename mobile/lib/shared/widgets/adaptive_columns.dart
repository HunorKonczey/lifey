import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// From this window width a client screen has room for two columns of cards.
/// Same 900 dp as the trainer's two-pane layout, for the same reason: at 600
/// two columns would each be a phone squeezed side by side.
const double adaptiveTwoColumnBreakpoint = 900;

/// From here up to the two-column breakpoint (a portrait tablet) one column is
/// kept readable by capping its width instead of stretching the cards across.
const double adaptiveSingleColumnBreakpoint = 600;

/// How wide the one column may grow, and the whole two-column block (a 1280 dp
/// tablet minus the 20 dp gutters still fills it, so the cards line up with the
/// header above them).
const double adaptiveSingleColumnMaxWidth = 720;
const double adaptiveTwoColumnMaxWidth = 1280;

/// The gap between the two columns.
const double adaptiveColumnGap = AppSpacing.s24;

/// A screen's cards in one list that becomes two columns on a tablet
/// (LIF-128).
///
/// [primary] is what the screen leads with and [secondary] what follows; on a
/// phone they are simply stacked in that order, so a screen written for the
/// phone keeps its order. Width alone decides, so a tablet held in portrait
/// gets the capped single column and landscape gets two.
class AdaptiveColumns extends StatelessWidget {
  const AdaptiveColumns({super.key, required this.primary, this.secondary = const []});

  final List<Widget> primary;
  final List<Widget> secondary;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    Widget stacked(List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        );

    if (width >= adaptiveTwoColumnBreakpoint) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: adaptiveTwoColumnMaxWidth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: stacked(primary)),
              const SizedBox(width: adaptiveColumnGap),
              Expanded(child: stacked(secondary)),
            ],
          ),
        ),
      );
    }

    final all = stacked([...primary, ...secondary]);
    if (width >= adaptiveSingleColumnBreakpoint) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: adaptiveSingleColumnMaxWidth),
          child: all,
        ),
      );
    }
    return all;
  }
}
