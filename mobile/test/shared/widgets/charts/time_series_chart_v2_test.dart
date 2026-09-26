import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/charts/time_series_chart.dart';

final _today = DateTime(2026, 9, 24);

List<TimeSeriesPoint> _series(List<double> values) => [
      for (var i = 0; i < values.length; i++)
        TimeSeriesPoint(date: _today.subtract(Duration(days: values.length - 1 - i)), value: values[i]),
    ];

Widget _host(Widget chart, {double textScale = 1, double width = 339}) => MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: Center(child: SizedBox(width: width, child: chart))),
        ),
      ),
    );

String _date(DateTime d) => '${d.month}/${d.day}';

void main() {
  final weights = _series([65.9, 65.6, 65.4, 65.1, 64.9, 64.7, 64.5]);

  testWidgets('without the v2 options nothing new is drawn (existing charts unchanged)', (tester) async {
    await tester.pumpWidget(_host(TimeSeriesChart(points: weights, dateLabelBuilder: _date)));
    expect(find.byType(Text), findsNothing); // no axis labels, no legend
    expect(find.byType(CustomPaint).last, paints..circle(radius: 3.5)); // per-point dots as before
  });

  testWidgets('a from-zero axis reads like the stats canvas: 13k / 6.5k / 0', (tester) async {
    await tester.pumpWidget(_host(TimeSeriesChart(
      points: _series([3140, 12612, 8532]),
      dateLabelBuilder: _date,
      yFromZero: true,
      axisLabelBuilder: (v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k' : v.toStringAsFixed(0),
    )));
    for (final l in ['13k', '6.5k', '0']) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
    // Top label above the middle one above the bottom one.
    expect(tester.getTopLeft(find.text('13k')).dy, lessThan(tester.getTopLeft(find.text('6.5k')).dy));
    expect(tester.getTopLeft(find.text('6.5k')).dy, lessThan(tester.getTopLeft(find.text('0')).dy));
  });

  testWidgets('around-the-data axis for weight: three descending labels', (tester) async {
    await tester.pumpWidget(_host(TimeSeriesChart(
      points: weights,
      dateLabelBuilder: _date,
      axisLabelBuilder: (v) => v.toStringAsFixed(1),
    )));
    final labels = tester.widgetList<Text>(find.byType(Text)).map((t) => double.parse(t.data!)).toList();
    expect(labels, hasLength(3));
    expect(labels[0], greaterThan(65.9)); // padded above the data
    expect(labels[2], lessThan(64.5));
    expect(labels[0] > labels[1] && labels[1] > labels[2], isTrue);
  });

  testWidgets('v2 look: no per-point dots, a ringed "today" dot', (tester) async {
    await tester.pumpWidget(_host(TimeSeriesChart(
      points: weights,
      dateLabelBuilder: _date,
      showPoints: false,
      highlightLast: true,
      gradientFill: true,
    )));
    final painter = find.byType(CustomPaint).last;
    expect(painter, isNot(paints..circle(radius: 3.5)));
    expect(painter, paints..circle(radius: 10, color: AppPalette.dark.card)..circle(radius: 6));
  });

  testWidgets('legend: both entries with a trend, daily only without', (tester) async {
    await tester.pumpWidget(_host(TimeSeriesChart(
      points: weights,
      dateLabelBuilder: _date,
      trendValues: const [null, null, 65.6, 65.4, 65.2, 65.0, 64.8],
      trendStyle: TrendStyle.dotted,
      legend: (daily: 'Daily', trend: '7-day average'),
    )));
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('7-day average'), findsOneWidget);

    await tester.pumpWidget(_host(TimeSeriesChart(
      points: weights,
      dateLabelBuilder: _date,
      legend: (daily: 'Daily', trend: '7-day average'),
    )));
    expect(find.text('Daily'), findsOneWidget);
    expect(find.text('7-day average'), findsNothing);
  });

  testWidgets('tapping still shows the tooltip with the axis in place', (tester) async {
    await tester.pumpWidget(_host(TimeSeriesChart(
      points: weights,
      dateLabelBuilder: _date,
      valueLabelBuilder: (v) => '${v.toStringAsFixed(1)} kg',
      axisLabelBuilder: (v) => v.toStringAsFixed(1),
      showPoints: false,
      highlightLast: true,
    )));
    // Nearest point by 2-D distance, so which one depends on where the tap
    // lands — what matters is that the axis didn't break hit-testing.
    final box = tester.getRect(find.byType(TimeSeriesChart));
    await tester.tapAt(box.center);
    await tester.pump();
    expect(find.textContaining(' kg'), findsOneWidget);
  });

  testWidgets('narrow phone at 130 % with axis and legend: no overflow', (tester) async {
    await tester.pumpWidget(_host(
      TimeSeriesChart(
        points: weights,
        dateLabelBuilder: _date,
        axisLabelBuilder: (v) => v.toStringAsFixed(1),
        trendValues: const [null, null, 65.6, 65.4, 65.2, 65.0, 64.8],
        trendStyle: TrendStyle.dotted,
        legend: (daily: 'Napi', trend: '7 napos átlag'),
      ),
      textScale: 1.3,
      width: 260,
    ));
    expect(tester.takeException(), isNull);
  });
}
