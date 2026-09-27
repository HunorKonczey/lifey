import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/format/lifey_format.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/dashboard/presentation/widgets/weekly_calories_card.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/charts/bar_chart.dart';
import 'package:lifey/shared/widgets/charts/time_series_chart.dart';

// Thursday 24 Sep 2026 — the canvas' day.
final _now = DateTime(2026, 9, 24, 9, 41);

/// Seven days oldest first, today last (canvas: F S S M T W T).
List<TimeSeriesPoint> _week(List<double> kcal) => [
      for (var i = 0; i < 7; i++)
        TimeSeriesPoint(date: DateTime(_now.year, _now.month, _now.day - (6 - i)), value: kcal[i]),
    ];

final _canvasWeek = _week([1680, 1850, 1470, 1760, 1910, 1600, 621]);

Future<void> _pump(
  WidgetTester tester,
  List<TimeSeriesPoint> points, {
  int? goal = 2360,
  Locale locale = const Locale('en'),
  double textScale = 1,
  double width = 411,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: WeeklyCaloriesCard(points: points, goal: goal, now: _now),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

LifeyBarChart _chart(WidgetTester tester) => tester.widget<LifeyBarChart>(find.byType(LifeyBarChart));

void main() {
  testWidgets('the canvas: title, seven bars, weekday letters F S S M T W T, today highlighted', (tester) async {
    await _pump(tester, _canvasWeek);
    expect(find.text('This week'), findsOneWidget);
    final bars = _chart(tester).bars;
    expect(bars.map((b) => b.label), ['F', 'S', 'S', 'M', 'T', 'W', 'T']);
    expect(bars.map((b) => b.highlighted), [false, false, false, false, false, false, true]);
    expect(bars.last.value, 621);
  });

  testWidgets('the average leaves out today\'s partial day', (tester) async {
    await _pump(tester, _canvasWeek);
    // (1680 + 1850 + 1470 + 1760 + 1910 + 1600) / 6 = 1711.67 — not 1556 with today's 621 in it.
    expect(find.textContaining('avg 1,712 kcal', findRichText: true), findsOneWidget);
  });

  testWidgets('days with nothing logged are empty columns and stay out of the average', (tester) async {
    await _pump(tester, _week([0, 2000, 0, 1000, 0, 0, 300]));
    expect(_chart(tester).bars.first.value, isNull);
    expect(find.textContaining('avg 1,500 kcal', findRichText: true), findsOneWidget);
  });

  testWidgets('no complete day yet: no average is shown', (tester) async {
    await _pump(tester, _week([0, 0, 0, 0, 0, 0, 500]));
    expect(find.textContaining('avg', findRichText: true), findsNothing);
  });

  testWidgets('the goal line is drawn at the calorie goal, and absent without one', (tester) async {
    await _pump(tester, _canvasWeek);
    expect(_chart(tester).goal, 2360);
    await _pump(tester, _canvasWeek, goal: null);
    expect(_chart(tester).goal, isNull);
  });

  testWidgets('each bar has a screen-reader label, and the chart a summary', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _canvasWeek);
    expect(find.bySemanticsLabel('Thursday, 621 kcal'), findsOneWidget);
    expect(find.bySemanticsLabel('Monday, 1,760 kcal'), findsOneWidget);
    expect(find.bySemanticsLabel('This week, average 1,712 kcal'), findsOneWidget);
    handle.dispose();
  });

  group('Hungarian', () {
    testWidgets('canvas 1.3: "Ezen a héten", "átl.", weekdays H K Sze Cs P Szo V', (tester) async {
      await _pump(tester, _canvasWeek, locale: const Locale('hu'));
      final f = LifeyFormat('hu');
      expect(find.text('Ezen a héten'), findsOneWidget);
      expect(find.textContaining('átl. ${f.integer(1712)} kcal', findRichText: true), findsOneWidget);
      // Thursday is today: Cs; Wednesday Sze; Saturday Szo — no repeated "Sz".
      expect(_chart(tester).bars.map((b) => b.label), ['P', 'Szo', 'V', 'H', 'K', 'Sze', 'Cs']);
    });

    for (final width in [411.0, 360.0]) {
      for (final scale in [1.0, 1.3]) {
        for (final theme in {'dark': AppTheme.dark, 'light': AppTheme.light}.entries) {
          testWidgets('fits without overflow — ${theme.key}, ${width.round()} dp, ×$scale', (tester) async {
            await _pump(tester, _canvasWeek,
                locale: const Locale('hu'), textScale: scale, width: width, theme: theme.value);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
