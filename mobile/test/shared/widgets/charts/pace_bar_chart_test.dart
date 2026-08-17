import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/shared/widgets/charts/pace_bar_chart.dart';

/// docs/cardio/61 §2 M33 — the pace bar chart's two rules that fail
/// *silently* if broken: the scale is inverted (taller = faster, so a slow
/// km must not look like a good one), and the partial last split stays out
/// of the evaluation entirely.

const _size = Size(330, 150);

PaceBar _bar(int seconds, {bool partial = false}) =>
    PaceBar(durationSeconds: seconds, label: '$seconds', partial: partial);

void main() {
  group('PaceBarGeometry', () {
    test('the faster split gets the taller bar', () {
      final geometry = PaceBarGeometry([_bar(300), _bar(240), _bar(360)], _size);

      final fast = geometry.barRect(1).height;
      final middle = geometry.barRect(0).height;
      final slow = geometry.barRect(2).height;

      expect(fast, greaterThan(middle));
      expect(middle, greaterThan(slow));
    });

    test('every bar sits on the baseline — only the top edge moves', () {
      final geometry = PaceBarGeometry([_bar(300), _bar(240)], _size);

      expect(geometry.barRect(0).bottom, _size.height);
      expect(geometry.barRect(1).bottom, _size.height);
    });

    test('identical splits share one height instead of dividing by zero', () {
      final geometry = PaceBarGeometry([_bar(300), _bar(300), _bar(300)], _size);

      expect(geometry.barRect(0).height, geometry.barRect(1).height);
      expect(geometry.barRect(1).height, geometry.barRect(2).height);
      expect(geometry.barRect(0).height, greaterThan(0));
    });

    test('the partial tail stays out of the scale', () {
      // The 40 s piece is the shortest duration in the list by far. If it
      // were scored, it would become the reference "fastest" and squash
      // every real split — the whole chart would then read as a slow run.
      final scoredOnly = PaceBarGeometry([_bar(300), _bar(240)], _size);
      final withPartial =
          PaceBarGeometry([_bar(300), _bar(240), _bar(40, partial: true)], _size);

      expect(withPartial.fastestSeconds, 240);
      expect(withPartial.slowestSeconds, 300);
      expect(withPartial.barRect(0).height, closeTo(scoredOnly.barRect(0).height, 0.001));
      expect(withPartial.barRect(1).height, closeTo(scoredOnly.barRect(1).height, 0.001));
    });

    test('the partial tail is never the tallest bar, nor the labelled one', () {
      final geometry =
          PaceBarGeometry([_bar(300), _bar(240), _bar(40, partial: true)], _size);

      expect(geometry.fastestIndex, 1);
      expect(geometry.barRect(2).height, lessThan(geometry.barRect(1).height));
      expect(geometry.barRect(2).height, lessThan(geometry.barRect(0).height));
    });

    test('a run of nothing but a partial piece has no scale and no label', () {
      final geometry = PaceBarGeometry([_bar(40, partial: true)], _size);

      expect(geometry.fastestIndex, isNull);
      expect(geometry.averageLineY, isNull);
      expect(geometry.barRect(0).height, greaterThan(0));
    });

    test('the average line lands between the fastest and the slowest bar', () {
      final geometry = PaceBarGeometry([_bar(360), _bar(300), _bar(240)], _size);
      final y = geometry.averageLineY!;

      // Y grows downward: the line sits below the tallest bar's top edge and
      // above the shortest one's.
      expect(y, greaterThan(geometry.barRect(2).top));
      expect(y, lessThan(geometry.barRect(0).top));
    });

    test('bars narrow once the run is long enough to crowd them', () {
      final wide = PaceBarGeometry([for (var i = 0; i < 5; i++) _bar(300 + i)], _size);
      final dense = PaceBarGeometry([for (var i = 0; i < 20; i++) _bar(300 + i)], _size);

      expect(wide.barWidth, greaterThan(dense.barWidth));
      expect(dense.barWidth, greaterThan(0));
    });

    test('a tap maps to the bar under it, and to nothing outside the chart', () {
      final geometry = PaceBarGeometry([_bar(300), _bar(240), _bar(360)], _size);

      expect(geometry.indexAt(10), 0);
      expect(geometry.indexAt(_size.width / 2), 1);
      expect(geometry.indexAt(_size.width - 5), 2);
      expect(geometry.indexAt(-1), isNull);
      expect(geometry.indexAt(_size.width + 20), isNull);
    });
  });

  group('PaceBarChart', () {
    Future<void> pump(WidgetTester tester, {required ValueChanged<int> onBarTap}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 330,
              child: PaceBarChart(
                bars: [_bar(300), _bar(240), _bar(360)],
                accent: Colors.green,
                onBarTap: onBarTap,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('tapping a bar reports its index', (tester) async {
      final tapped = <int>[];
      await pump(tester, onBarTap: tapped.add);

      final chart = tester.getRect(find.byType(PaceBarChart));
      await tester.tapAt(Offset(chart.left + chart.width / 2, chart.center.dy));

      expect(tapped, [1]);
    });

    testWidgets('renders without exploding on an empty list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PaceBarChart(bars: [], accent: Colors.green),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
