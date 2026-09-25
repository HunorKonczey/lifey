import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/charts/bar_chart.dart';
import 'package:lifey/shared/widgets/charts/chart_math.dart';

void main() {
  group('niceAxisMax — the canvases\' axes', () {
    test('rounds up to two significant digits', () {
      expect(niceAxisMax(2360), 2400); // dashboard goal
      expect(niceAxisMax(12612), 13000); // stats steps
      expect(niceAxisMax(99.5), 100);
      expect(niceAxisMax(1000), 1000);
      expect(niceAxisMax(0.83), closeTo(0.83, 1e-9));
    });

    test('small integer counts get one step of headroom', () {
      expect(niceAxisMax(6, integer: true), 7); // stats workouts
      expect(niceAxisMax(1, integer: true), 2);
      expect(niceAxisMax(12, integer: true), 12);
    });

    test('an empty chart still has an axis', () {
      expect(niceAxisMax(0), 1);
      expect(niceAxisMax(double.nan), 1);
    });
  });

  group('yAxisTicks', () {
    test('the goal counts toward the axis top', () {
      expect(yAxisTicks(1910, goal: 2360), [2400, 1200, 0]);
      expect(yAxisTicks(0, goal: 2360), [2400, 1200, 0]);
    });

    test('half is exact, not rounded', () {
      expect(yAxisTicks(6, integer: true), [7, 3.5, 0]);
      expect(yAxisTicks(12612), [13000, 6500, 0]);
    });
  });

  group('averageExcludingPartialToday (plan §9 risk 5)', () {
    final now = DateTime(2026, 9, 24, 8, 30);
    ({DateTime day, double? value}) d(int daysAgo, double? v) =>
        (day: DateTime(2026, 9, 24 - daysAgo, 13), value: v);

    test('today\'s half-logged day is left out', () {
      final avg = averageExcludingPartialToday([d(2, 1800), d(1, 2000), d(0, 300)], now);
      expect(avg, 1900);
    });

    test('missing days are skipped; zeros only with ignoreZero', () {
      final points = [d(3, 1800), d(2, null), d(1, 0)];
      expect(averageExcludingPartialToday(points, now), 900);
      expect(averageExcludingPartialToday(points, now, ignoreZero: true), 1800);
    });

    test('only today → no average rather than a misleading one', () {
      expect(averageExcludingPartialToday([d(0, 621)], now), isNull);
    });

    test('a value logged at 00:10 today is still today', () {
      final points = [(day: DateTime(2026, 9, 24, 0, 10), value: 500.0), d(1, 1500)];
      expect(averageExcludingPartialToday(points, now), 1500);
    });
  });

  group('LifeyBarChart', () {
    Widget host(Widget chart, {Locale locale = const Locale('en'), double textScale = 1, double width = 339}) => MaterialApp(
          theme: AppTheme.dark,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(body: Center(child: SizedBox(width: width, child: chart))),
            ),
          ),
        );

    List<BarDatum> week(List<String> labels) => [
          for (final (i, l) in labels.indexed)
            BarDatum(label: l, value: const <double>[1680, 1850, 1471, 1759, 1910, 1601, 621][i], highlighted: i == 6),
        ];

    testWidgets('axis labels, bold "today", goal-driven top', (tester) async {
      await tester.pumpWidget(host(LifeyBarChart(
        bars: week(['F', 'S', 'S', 'M', 'T', 'W', 'T']),
        color: AppMetricColors.dark.calories,
        goal: 2360,
      )));
      await tester.pumpAndSettle();
      for (final l in ['2.4k', '1.2k', '0']) {
        expect(find.text(l), findsOneWidget, reason: l);
      }
      final labels = tester.widgetList<Text>(find.text('T')).toList();
      expect(labels.last.style!.fontWeight, FontWeight.w800);
      expect(labels.first.style!.fontWeight, FontWeight.w600);
    });

    testWidgets('an integer chart labels its half as 3.5', (tester) async {
      await tester.pumpWidget(host(LifeyBarChart(
        bars: [for (final v in const <double>[4, 5, 6, 4, 3]) BarDatum(label: 'w', value: v)],
        color: AppMetricColors.dark.protein,
        integer: true,
        height: 150,
        barGap: 14,
      )));
      expect(find.text('7'), findsOneWidget);
      expect(find.text('3.5'), findsOneWidget);
    });

    testWidgets('Hungarian weekdays at 130 % on a narrow phone do not overflow', (tester) async {
      await tester.pumpWidget(host(
        LifeyBarChart(
          bars: week(['P', 'Szo', 'V', 'H', 'K', 'Sze', 'Cs']),
          color: AppMetricColors.dark.calories,
          goal: 2360,
        ),
        locale: const Locale('hu'),
        textScale: 1.3,
        width: 280,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('2,4k'), findsOneWidget);
    });

    testWidgets('each bar can speak for itself', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(LifeyBarChart(
        bars: const [
          BarDatum(label: 'M', value: 1680, semanticsLabel: 'Monday, 1,680 kcal'),
          BarDatum(label: 'T', value: 621, highlighted: true, semanticsLabel: 'Tuesday, 621 kcal'),
        ],
        color: AppMetricColors.dark.calories,
        semanticsLabel: 'This week, average 1,680 kcal',
      )));
      expect(find.bySemanticsLabel('Monday, 1,680 kcal'), findsOneWidget);
      expect(find.bySemanticsLabel('This week, average 1,680 kcal'), findsOneWidget);
      expect(find.bySemanticsLabel('2.4k'), findsNothing); // axis noise stays silent
      handle.dispose();
    });

    testWidgets('many bars label only the chosen ones, without overflow', (tester) async {
      // 30 daily bars: only every seventh carries a date; the rest are empty.
      await tester.pumpWidget(host(LifeyBarChart(
        bars: [
          for (var i = 0; i < 30; i++)
            BarDatum(label: (29 - i) % 7 == 0 ? 'Sep ${i + 1}' : '', value: 100.0 + i, highlighted: i == 29),
        ],
        color: AppMetricColors.dark.calories,
        barGap: 3,
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Sep 30'), findsOneWidget);
      expect(find.text('Sep 23'), findsOneWidget);
      expect(find.text('Sep 22'), findsNothing);
    });

    testWidgets('no data at all still draws an axis without errors', (tester) async {
      await tester.pumpWidget(host(LifeyBarChart(
        bars: const [BarDatum(label: 'M', value: null), BarDatum(label: 'T', value: 0)],
        color: AppMetricColors.dark.calories,
      )));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('1'), findsOneWidget);
    });
  });
}
