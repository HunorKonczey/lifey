import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/animated_fill.dart';
import 'package:lifey/shared/widgets/ds/metric_bar.dart';
import 'package:lifey/shared/widgets/ds/metric_tile.dart';
import 'package:lifey/shared/widgets/ds/progress_ring.dart';

Widget _host(Widget child, {bool reducedMotion = false, double textScale = 1, double width = 371}) => MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reducedMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
        ),
      ),
    );

/// Shows the current fill value as text.
Widget _fill(double value, {Duration delay = Duration.zero, bool reducedMotion = false}) => _host(
      AnimatedFill(
        values: [value],
        delay: delay,
        builder: (context, v) => Text(v.single.toStringAsFixed(3)),
      ),
      reducedMotion: reducedMotion,
    );

double _shown(WidgetTester tester) => double.parse(tester.widget<Text>(find.byType(Text)).data!);

void main() {
  group('ringSweeps — no arc ever passes 360°', () {
    test('within the goal', () {
      expect(ringSweeps(0), (lap: 0.0, overflow: 0.0));
      expect(ringSweeps(0.22), (lap: 0.22, overflow: 0.0));
      expect(ringSweeps(1), (lap: 1.0, overflow: 0.0));
    });

    test('past the goal a second lap starts', () {
      final s = ringSweeps(1.3);
      expect(s.lap, 1);
      expect(s.overflow, closeTo(0.3, 1e-9));
    });

    test('the overflow lap is capped at one full turn', () {
      expect(ringSweeps(3), (lap: 1.0, overflow: 1.0));
    });

    test('negative and NaN count as empty', () {
      expect(ringSweeps(-0.5), (lap: 0.0, overflow: 0.0));
      expect(ringSweeps(double.nan), (lap: 0.0, overflow: 0.0));
    });
  });

  group('RatioBar.fractions', () {
    test('against the kcal goal — the canvas day budget', () {
      // P 29 g × 4, C 88 g × 4, F 20 g × 9 of 2 360 kcal → 5 %, 15 %, 8 %.
      final f = RatioBar.fractions([116, 352, 180], 2360);
      expect(f[0], closeTo(0.049, 0.001));
      expect(f[1], closeTo(0.149, 0.001));
      expect(f[2], closeTo(0.076, 0.001));
    });

    test('over the goal the segments scale down to fill the bar', () {
      final f = RatioBar.fractions([2000, 1000], 2360);
      expect(f.reduce((a, b) => a + b), closeTo(1, 1e-9));
      expect(f[0], closeTo(2 / 3, 1e-9));
    });

    test('without a total it is a 100 % split', () {
      final f = RatioBar.fractions([416, 752, 522], null);
      expect(f.reduce((a, b) => a + b), closeTo(1, 1e-9));
    });

    test('nothing logged, negatives and NaN are empty', () {
      expect(RatioBar.fractions([0, 0, 0], 2360), [0, 0, 0]);
      expect(RatioBar.fractions([-5, double.nan, 10], null), [0, 0, 1]);
    });
  });

  group('AnimatedFill', () {
    testWidgets('fills in from 0 on first appearance', (tester) async {
      await tester.pumpWidget(_fill(0.6));
      expect(_shown(tester), 0);
      await tester.pump(AppMotion.fill ~/ 2);
      expect(_shown(tester), inExclusiveRange(0, 0.6));
      await tester.pumpAndSettle();
      expect(_shown(tester), 0.6);
    });

    testWidgets('a stagger delay holds the fill at 0 first', (tester) async {
      await tester.pumpWidget(_fill(0.6, delay: AppMotion.staggered(2)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_shown(tester), 0);
      await tester.pumpAndSettle();
      expect(_shown(tester), 0.6);
    });

    testWidgets('after a change only the difference animates', (tester) async {
      await tester.pumpWidget(_fill(0.4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_fill(0.6));
      await tester.pump();
      expect(_shown(tester), closeTo(0.4, 0.01)); // starts from where it was, not 0
      await tester.pump(AppMotion.fill ~/ 2);
      expect(_shown(tester), inExclusiveRange(0.4, 0.6));
      await tester.pumpAndSettle();
      expect(_shown(tester), 0.6);
    });

    testWidgets('an equal value on rebuild does not restart it', (tester) async {
      await tester.pumpWidget(_fill(0.4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_fill(0.4));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion shows the value at once', (tester) async {
      await tester.pumpWidget(_fill(0.6, reducedMotion: true));
      expect(_shown(tester), 0.6);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('MetricBar', () {
    testWidgets('fills its share of the width, clamped at full', (tester) async {
      await tester.pumpWidget(_host(MetricBar(progress: 0.25, color: AppMetricColors.dark.protein), width: 200));
      await tester.pumpAndSettle();
      // FractionallySizedBox itself takes the full width; the coloured fill
      // is its child.
      final fill = find.descendant(of: find.byType(FractionallySizedBox), matching: find.byType(DecoratedBox));
      expect(tester.getSize(fill).width, closeTo(50, 0.5));
      await tester.pumpWidget(_host(MetricBar(progress: 1.8, color: AppMetricColors.dark.protein), width: 200));
      await tester.pumpAndSettle();
      expect(tester.getSize(fill).width, closeTo(200, 0.5));
    });
  });

  testWidgets('ProgressRing paints past 300 % without errors and reads its label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(ProgressRing(
      progress: 3,
      color: AppMetricColors.dark.calories,
      semanticsLabel: 'Calories, 300 % of goal',
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Calories, 300 % of goal'), findsOneWidget);
    // Stays 144 even though the host forces a 371 px width.
    expect(tester.getSize(find.descendant(of: find.byType(ProgressRing), matching: find.byType(CustomPaint)).first),
        const Size.square(144));
    handle.dispose();
  });

  group('MetricTile', () {
    Widget pair({double textScale = 1}) => _host(
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: MetricTile(
                icon: Icons.water_drop_rounded,
                label: 'Víz',
                value: '0,99',
                unit: '/ 2,6 L',
                color: AppMetricColors.dark.water,
                progress: 0.38,
                onAction: () {},
                actionTooltip: 'Víz hozzáadása',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricTile(
                icon: Icons.directions_walk_rounded,
                label: 'Lépések',
                value: '6 412',
                unit: '/ 10 000',
                color: AppMetricColors.dark.steps,
                progress: 0.64,
              ),
            ),
          ]),
          textScale: textScale,
        );

    testWidgets('side by side, the values line up with or without the + button', (tester) async {
      await tester.pumpWidget(pair());
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.textContaining('0,99')).dy, tester.getTopLeft(find.textContaining('6 412')).dy);
    });

    testWidgets('the + button is a 48 dp target with a tooltip, and works', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(MetricTile(
        icon: Icons.water_drop_rounded,
        label: 'Water',
        value: '0.99',
        color: AppMetricColors.dark.water,
        onAction: () => taps++,
        actionTooltip: 'Add water',
      )));
      expect(tester.getSize(find.byType(IconButton)), const Size.square(48));
      await tester.tap(find.byTooltip('Add water'));
      expect(taps, 1);
    });

    testWidgets('Hungarian at 130 % in half width: wraps, never overflows', (tester) async {
      await tester.pumpWidget(pair(textScale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a summary label replaces the parts; the button stays reachable', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(MetricTile(
        icon: Icons.water_drop_rounded,
        label: 'Water',
        value: '0.99',
        unit: '/ 2.6 L',
        color: AppMetricColors.dark.water,
        onAction: () {},
        actionTooltip: 'Add water',
        semanticsLabel: 'Water, 0.99 of 2.6 litres',
      )));
      expect(find.bySemanticsLabel('Water, 0.99 of 2.6 litres'), findsOneWidget);
      // The button is its own node (not merged into the summary); Flutter
      // exposes an icon button's name as its tooltip.
      expect(
        tester.getSemantics(find.byType(IconButton)),
        isSemantics(tooltip: 'Add water', hasTapAction: true),
      );
      expect(find.bySemanticsLabel('0.99'), findsNothing);
      handle.dispose();
    });
  });
}
