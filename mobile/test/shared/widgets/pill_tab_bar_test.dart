import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/shared/widgets/pill_tab_bar.dart';

void main() {
  const labels = ['Étkezések', 'Receptek', 'Ételek', 'Makrók'];

  Future<void> pump(WidgetTester tester, double scale) async {
    tester.view.physicalSize = const Size(411, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(size: const Size(411, 900), textScaler: TextScaler.linear(scale)),
        child: DefaultTabController(
          length: labels.length,
          child: Builder(
            builder: (context) => Scaffold(
              body: PillTabBar(
                controller: DefaultTabController.of(context),
                horizontalMargin: 20,
                tabs: [for (final l in labels) Tab(text: l)],
              ),
            ),
          ),
        ),
      ),
    ));
  }

  // Hungarian at 130 % wrapped "Étkezések" and "Receptek" onto a second
  // line that the 46 px bar clipped (R0 emulator review); the labels now
  // lay out on one line and shrink to their share of the bar.
  for (final scale in [1.0, 1.3]) {
    testWidgets('HU labels stay inside their own tab at ${(scale * 100).round()} %', (tester) async {
      await pump(tester, scale);
      for (final l in labels) {
        final tab = tester.getRect(find.ancestor(of: find.text(l), matching: find.byType(Tab)));
        final text = tester.getRect(find.text(l));
        final paragraph = tester.renderObject<RenderParagraph>(find.text(l));
        expect(paragraph.size.width, closeTo(paragraph.getMaxIntrinsicWidth(double.infinity), 0.5),
            reason: '$l is laid out on one line');
        expect(text.left, greaterThanOrEqualTo(tab.left - 0.5), reason: l);
        expect(text.right, lessThanOrEqualTo(tab.right + 0.5), reason: l);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
