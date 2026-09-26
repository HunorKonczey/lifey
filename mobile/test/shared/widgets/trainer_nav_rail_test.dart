import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/shared/widgets/adaptive_bottom_nav.dart' show AdaptiveNavDestination;
import 'package:lifey/shared/widgets/trainer_nav_rail.dart';

const _destinations = [
  AdaptiveNavDestination(icon: Icons.group_outlined, selectedIcon: Icons.group, label: 'Ügyfelek'),
  AdaptiveNavDestination(icon: Icons.calendar_month_outlined, selectedIcon: Icons.calendar_month, label: 'Naptár'),
  AdaptiveNavDestination(icon: Icons.assignment_outlined, selectedIcon: Icons.assignment, label: 'Kiosztott'),
  AdaptiveNavDestination(icon: Icons.calendar_view_week_outlined, selectedIcon: Icons.calendar_view_week, label: 'Programok'),
];

Future<void> _pump(
  WidgetTester tester, {
  int selected = 0,
  ValueChanged<int>? onSelected,
  double textScale = 1,
  Size size = const Size(1280, 800),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Row(
          children: [
            TrainerNavRail(
              selectedIndex: selected,
              onDestinationSelected: onSelected ?? (_) {},
              destinations: _destinations,
            ),
            const Expanded(child: SizedBox.expand()),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('is 96 dp wide and names every destination', (tester) async {
    await _pump(tester);

    expect(tester.getSize(find.byType(TrainerNavRail)).width, 96);
    for (final d in _destinations) {
      expect(find.text(d.label), findsOneWidget);
    }
  });

  testWidgets('the active destination is a filled primary pill with the filled icon', (tester) async {
    await _pump(tester, selected: 1);

    expect(find.byIcon(Icons.calendar_month), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);
    expect(find.byIcon(Icons.group_outlined), findsOneWidget);

    final pill = tester.widget<Container>(
      find.ancestor(of: find.byIcon(Icons.calendar_month), matching: find.byType(Container)).first,
    );
    final context = tester.element(find.byIcon(Icons.calendar_month));
    expect((pill.decoration! as BoxDecoration).color, Theme.of(context).colorScheme.primary);
  });

  testWidgets('tapping a destination reports its index', (tester) async {
    int? picked;
    await _pump(tester, onSelected: (i) => picked = i);

    await tester.tap(find.text('Kiosztott'));
    expect(picked, 2);
  });

  testWidgets('each item is a button that says whether it is selected', (tester) async {
    await _pump(tester, selected: 3);

    final selected = tester.getSemantics(find.bySemanticsLabel('Programok'));
    final other = tester.getSemantics(find.bySemanticsLabel('Naptár'));
    expect(selected.flagsCollection.isSelected, isNot(other.flagsCollection.isSelected));
    expect(selected.flagsCollection.isButton, isTrue);
  });

  for (final (mode, theme) in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
    testWidgets('fits a landscape phone-height window at x 1.3 ($mode), scrolling instead of overflowing', (tester) async {
      await _pump(tester, textScale: 1.3, size: const Size(1000, 420), theme: theme);
      expect(tester.takeException(), isNull);
    });
  }
}
