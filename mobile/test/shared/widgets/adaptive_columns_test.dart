import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/shared/widgets/adaptive_columns.dart';

Widget _card(String key) => SizedBox(key: ValueKey(key), height: 100, child: const ColoredBox(color: Colors.grey));

Future<void> _pump(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AdaptiveColumns(
            primary: [_card('hero'), _card('tiles')],
            secondary: [_card('week'), _card('meals')],
          ),
        ),
      ),
    ),
  );
}

Rect _rect(WidgetTester tester, String key) => tester.getRect(find.byKey(ValueKey(key)));

void main() {
  testWidgets('a phone stacks everything in one column, primary first', (tester) async {
    await _pump(tester, 411);

    final order = ['hero', 'tiles', 'week', 'meals'];
    for (var i = 1; i < order.length; i++) {
      expect(_rect(tester, order[i]).top, greaterThanOrEqualTo(_rect(tester, order[i - 1]).bottom));
      expect(_rect(tester, order[i]).left, _rect(tester, order[0]).left);
    }
    // The full width minus the 20 dp gutters.
    expect(_rect(tester, 'hero').width, 411 - 40);
  });

  testWidgets('a portrait tablet keeps one column but caps its width', (tester) async {
    await _pump(tester, 800);

    expect(_rect(tester, 'hero').width, adaptiveSingleColumnMaxWidth);
    expect(_rect(tester, 'hero').center.dx, 400, reason: 'centered');
    expect(_rect(tester, 'week').top, greaterThanOrEqualTo(_rect(tester, 'tiles').bottom));
  });

  testWidgets('a landscape tablet lays primary and secondary side by side', (tester) async {
    await _pump(tester, 1280);

    final hero = _rect(tester, 'hero');
    final week = _rect(tester, 'week');
    expect(week.left, greaterThanOrEqualTo(hero.right + adaptiveColumnGap));
    expect(week.top, hero.top, reason: 'both columns start at the top');
    expect(_rect(tester, 'tiles').left, hero.left);
    expect(_rect(tester, 'meals').left, week.left);
    expect(hero.width, closeTo(week.width, 0.5));
    // Capped, and centered: the block is no wider than the maximum.
    expect(week.right - hero.left, lessThanOrEqualTo(adaptiveTwoColumnMaxWidth));
  });

  testWidgets('the breakpoint is exact: 899 dp is one column, 900 dp is two', (tester) async {
    await _pump(tester, 899);
    expect(_rect(tester, 'week').left, _rect(tester, 'hero').left);

    await _pump(tester, 900);
    await tester.pump();
    expect(_rect(tester, 'week').left, greaterThan(_rect(tester, 'hero').left));
  });
}
