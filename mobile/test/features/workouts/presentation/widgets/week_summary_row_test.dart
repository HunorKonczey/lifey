import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/domain/week_summary.dart';
import 'package:lifey/features/workouts/presentation/widgets/week_summary_row.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/lifey_card.dart';

Future<void> _pump(
  WidgetTester tester,
  WeekSummary summary, {
  UnitSystem units = UnitSystem.metric,
  Locale locale = const Locale('en'),
  double textScale = 1,
  double width = 411,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(20), child: WeekSummaryRow(summary: summary, unitSystem: units)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _canvas = WeekSummary(workouts: 3, minutes: 96, distanceMeters: 5210);

void main() {
  testWidgets('the canvas week: 3 · 96 · 5.2 with their labels', (tester) async {
    await _pump(tester, _canvas);

    expect(find.text('3'), findsOneWidget);
    expect(find.text('workouts this week'), findsOneWidget);
    expect(find.text('96'), findsOneWidget);
    expect(find.text('min this week'), findsOneWidget);
    expect(find.text('5.2'), findsOneWidget);
    expect(find.text('km this week'), findsOneWidget);
  });

  testWidgets('one workout reads in the singular', (tester) async {
    await _pump(tester, const WeekSummary(workouts: 1, minutes: 30, distanceMeters: 0));

    expect(find.text('workout this week'), findsOneWidget);
    expect(find.text('0.0'), findsOneWidget);
  });

  testWidgets('imperial units show miles', (tester) async {
    await _pump(tester, const WeekSummary(workouts: 1, minutes: 30, distanceMeters: 16093.44), units: UnitSystem.imperial);

    expect(find.text('10.0'), findsOneWidget);
    expect(find.text('mi this week'), findsOneWidget);
  });

  testWidgets('Hungarian: decimal comma, labels', (tester) async {
    await _pump(tester, _canvas, locale: const Locale('hu'));

    expect(find.text('5,2'), findsOneWidget);
    expect(find.text('edzés a héten'), findsOneWidget);
    expect(find.text('km a héten'), findsOneWidget);
  });

  for (final width in [411.0, 360.0]) {
    testWidgets('no overflow at ${width.toInt()} dp, text x1.3, HU', (tester) async {
      await _pump(tester, _canvas, locale: const Locale('hu'), textScale: 1.3, width: width);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the three tiles have the same height', (tester) async {
    await _pump(tester, _canvas, textScale: 1.3, width: 360);

    final tiles = find.byType(LifeyCard);
    expect(tiles, findsNWidgets(3));
    final heights = [for (var i = 0; i < 3; i++) tester.getSize(tiles.at(i)).height];
    expect(heights.toSet().length, 1);
  });
}
