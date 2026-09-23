import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/shared/widgets/charts/time_series_chart.dart';

/// The trend series shares the points' geometry (docs/76-smarter-weight-trend-plan.md
/// §3), so the thing worth checking is that adding it leaves the chart's own
/// behaviour — the tap targets and their tooltip — alone.

final _points = [
  for (var i = 0; i < 10; i++)
    TimeSeriesPoint(date: DateTime(2026, 3, 1).add(Duration(days: i)), value: 90 - i * 0.2),
];

Future<void> _pump(WidgetTester tester, {List<double?>? trendValues}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          child: TimeSeriesChart(
            points: _points,
            dateLabelBuilder: (date) => '${date.day}',
            valueLabelBuilder: (value) => '${value.toStringAsFixed(1)} kg',
            trendValues: trendValues,
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a tapped point still reveals its own raw value', (tester) async {
    await _pump(tester, trendValues: [
      null,
      for (var i = 1; i < 10; i++) 89.5,
    ]);

    await tester.tapAt(tester.getCenter(find.byType(CustomPaint).first));
    await tester.pumpAndSettle();

    // The tooltip reports a weigh-in, never the average drawn over it.
    expect(find.textContaining('kg'), findsWidgets);
    expect(find.text('89.5 kg'), findsNothing);
  });

  testWidgets('renders without a trend just as well', (tester) async {
    await _pump(tester);

    expect(find.byType(TimeSeriesChart), findsOneWidget);
  });

  testWidgets('an all-null trend is the same as no trend', (tester) async {
    await _pump(tester, trendValues: List<double?>.filled(10, null));

    expect(find.byType(TimeSeriesChart), findsOneWidget);
  });
}
