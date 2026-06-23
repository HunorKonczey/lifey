import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/shared/widgets/charts/time_series_chart.dart';

void main() {
  final points = [
    TimeSeriesPoint(date: DateTime(2024, 1, 1), value: 10),
    TimeSeriesPoint(date: DateTime(2024, 1, 2), value: 20),
  ];

  Future<void> pumpChart(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: TimeSeriesChart(
              points: points,
              dateLabelBuilder: (date) => 'day-${date.day}',
              valueLabelBuilder: (value) => '${value.toStringAsFixed(1)} units',
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('no tooltip is shown before any tap', (tester) async {
    await pumpChart(tester);

    expect(find.text('20.0 units'), findsNothing);
    expect(find.text('10.0 units'), findsNothing);
  });

  testWidgets('tapping near a point reveals its tooltip with the exact value + date', (
    tester,
  ) async {
    await pumpChart(tester);

    // The chart spans the SizedBox's 300px width with an 8px side padding on
    // each side (see _ChartGeometry), so the second point sits at the right
    // edge (x≈292) and the first at the left edge (x≈8). Tapping well to the
    // right is unambiguously closer to the second point regardless of y.
    final topLeft = tester.getTopLeft(find.byType(TimeSeriesChart));
    await tester.tapAt(topLeft + const Offset(250, 100));
    await tester.pump();

    expect(find.text('20.0 units'), findsOneWidget);
    expect(find.text('day-2'), findsOneWidget);
  });

  testWidgets('tapping the same point again closes the tooltip', (tester) async {
    await pumpChart(tester);

    final topLeft = tester.getTopLeft(find.byType(TimeSeriesChart));
    final tapPosition = topLeft + const Offset(250, 100);

    await tester.tapAt(tapPosition);
    await tester.pump();
    expect(find.text('20.0 units'), findsOneWidget);

    await tester.tapAt(tapPosition);
    await tester.pump();
    expect(find.text('20.0 units'), findsNothing);
  });

  testWidgets('tapping a different point moves the tooltip', (tester) async {
    await pumpChart(tester);

    final topLeft = tester.getTopLeft(find.byType(TimeSeriesChart));

    await tester.tapAt(topLeft + const Offset(250, 100));
    await tester.pump();
    expect(find.text('20.0 units'), findsOneWidget);
    expect(find.text('10.0 units'), findsNothing);

    await tester.tapAt(topLeft + const Offset(20, 100));
    await tester.pump();
    expect(find.text('10.0 units'), findsOneWidget);
    expect(find.text('20.0 units'), findsNothing);
  });
}
