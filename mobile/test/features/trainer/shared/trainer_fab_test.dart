import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/ads/nav_reserved_space.dart';
import 'package:lifey/features/trainer/shared/trainer_fab.dart';

/// The trainer shell draws `AdaptiveBottomNav` as a floating pill over the
/// body, so a screen's own FAB has to be lifted clear of it by hand — it used
/// to sit on top of the nav. Both helpers are checked against the same
/// `navSlotHeight` the client shell uses.

const _safeBottom = 34.0;
const _screenHeight = 800.0;

Widget _wrap(Widget child, {double bottomPadding = _safeBottom}) {
  return MediaQuery(
    data: MediaQueryData(
      size: const Size(400, _screenHeight),
      padding: EdgeInsets.only(bottom: bottomPadding),
      viewPadding: EdgeInsets.only(bottom: bottomPadding),
    ),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('a Scaffold FAB clears the nav pill', (tester) async {
    tester.view.physicalSize = const Size(400, _screenHeight);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(Scaffold(
      floatingActionButton: TrainerFabPadding(
        child: FloatingActionButton.extended(
          onPressed: () {},
          label: const Text('Assign'),
        ),
      ),
      body: const SizedBox.expand(),
    )));

    final fab = tester.getRect(find.byType(FloatingActionButton));
    final gapBelowFab = _screenHeight - fab.bottom;

    // Above the nav's own slot (58 + 26) and its safe area — the nav's top
    // edge is the line the FAB must not cross.
    expect(gapBelowFab, greaterThanOrEqualTo(navSlotHeight + _safeBottom));
  });

  testWidgets('a hand-placed FAB is positioned above the nav too', (tester) async {
    late double bottom;
    await tester.pumpWidget(_wrap(Builder(
      builder: (context) {
        bottom = trainerFabBottom(context);
        return const SizedBox.shrink();
      },
    )));

    expect(bottom, navSlotHeight + _safeBottom + fabGap);
  });

  testWidgets('inside a SafeArea the safe area is not counted twice', (tester) async {
    late double bottom;
    await tester.pumpWidget(_wrap(SafeArea(
      child: Builder(
        builder: (context) {
          bottom = trainerFabBottom(context);
          return const SizedBox.shrink();
        },
      ),
    )));

    // SafeArea has already consumed the inset, so the box the FAB is
    // positioned in ends where the safe area starts.
    expect(bottom, navSlotHeight + fabGap);
  });
}
