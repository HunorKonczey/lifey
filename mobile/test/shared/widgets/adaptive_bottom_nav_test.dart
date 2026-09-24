import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/ads/nav_reserved_space.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/shared/widgets/adaptive_bottom_nav.dart';
import 'package:lifey/shared/widgets/nav_collapse_controller.dart';

const _hu = ['Áttekintés', 'Étrend', 'Edzések', 'Súly', 'Statisztika'];

Widget _nav({
  required int selected,
  ValueChanged<int>? onTap,
  NavCollapseController? controller,
  double width = 411,
  double textScale = 1,
  double safeBottom = 0,
  bool reducedMotion = false,
}) =>
    MaterialApp(
      theme: AppTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          padding: EdgeInsets.only(bottom: safeBottom),
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
        ),
        child: NavCollapseScope(
          controller: controller ?? NavCollapseController(),
          child: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: Center(
              heightFactor: 1,
              child: SizedBox(
                width: width,
                child: AdaptiveBottomNav(
                  selectedIndex: selected,
                  onDestinationSelected: onTap ?? (_) {},
                  destinations: [
                    for (final l in _hu)
                      AdaptiveNavDestination(icon: Icons.circle_outlined, selectedIcon: Icons.circle, label: l),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

Finder _bar() => find.descendant(of: find.byType(AdaptiveBottomNav), matching: find.byType(AnimatedContainer)).first;

void main() {
  testWidgets('only the active tab shows its label', (tester) async {
    await tester.pumpWidget(_nav(selected: 0));
    await tester.pumpAndSettle();
    expect(find.text('Áttekintés'), findsOneWidget);
    for (final l in _hu.skip(1)) {
      expect(find.text(l), findsNothing);
    }
  });

  testWidgets('screen readers get every tab, and which one is selected (plan §9 risk 8)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_nav(selected: 4));
    await tester.pumpAndSettle();
    for (final l in _hu) {
      expect(find.bySemanticsLabel(l), findsOneWidget, reason: l);
    }
    expect(tester.getSemantics(find.bySemanticsLabel('Statisztika')), isSemantics(isSelected: true, isButton: true));
    expect(tester.getSemantics(find.bySemanticsLabel('Étrend')), isSemantics(isSelected: false));
    handle.dispose();
  });

  testWidgets('every tab is a 48 dp target and a tap selects it', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(_nav(selected: 0, onTap: (i) => tapped = i));
    await tester.pumpAndSettle();
    final items = find.descendant(of: _bar(), matching: find.byType(GestureDetector));
    expect(items, findsNWidgets(5));
    for (final item in items.evaluate()) {
      expect(tester.getSize(find.byWidget(item.widget)).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(find.byWidget(item.widget)).width, greaterThanOrEqualTo(48));
    }
    await tester.tap(items.at(3));
    expect(tapped, 3);
  });

  for (final index in [0, 4]) {
    testWidgets('the longest Hungarian names fit a 360 px phone at 130 % (tab $index)', (tester) async {
      await tester.pumpWidget(_nav(selected: index, width: 360, textScale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('68 tall; flattens to 56 when collapsed and back', (tester) async {
    final controller = NavCollapseController();
    await tester.pumpWidget(_nav(selected: 1, controller: controller));
    await tester.pumpAndSettle();
    expect(tester.getSize(_bar()).height, AdaptiveBottomNav.barHeight);
    controller.collapse();
    await tester.pumpAndSettle();
    expect(tester.getSize(_bar()).height, AdaptiveBottomNav.collapsedHeight);
    controller.expand();
    await tester.pumpAndSettle();
    expect(tester.getSize(_bar()).height, AdaptiveBottomNav.barHeight);
  });

  testWidgets('reserves exactly navSlotHeight + safe area, so FAB and banner math holds', (tester) async {
    await tester.pumpWidget(_nav(selected: 0, safeBottom: 24));
    expect(tester.getSize(find.byType(AdaptiveBottomNav)).height, navSlotHeight + 24);
    expect(AdaptiveBottomNav.barHeight + AdaptiveBottomNav.bottomGap, navSlotHeight);
  });

  testWidgets('under reduced motion a tab switch does not animate', (tester) async {
    await tester.pumpWidget(_nav(selected: 0, reducedMotion: true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_nav(selected: 2, reducedMotion: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('Edzések'), findsOneWidget);
  });
}
