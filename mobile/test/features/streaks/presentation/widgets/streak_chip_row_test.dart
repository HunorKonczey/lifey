import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/streaks/domain/streak.dart';
import 'package:lifey/features/streaks/presentation/widgets/streak_chip_row.dart';
import 'package:lifey/l10n/app_localizations.dart';

Streak _streak(
  StreakMetric metric, {
  required int current,
  int? best,
  required bool todayMet,
}) {
  return Streak(metric: metric, current: current, best: best ?? current, todayMet: todayMet);
}

Future<void> _pump(WidgetTester tester, List<Streak> streaks, {VoidCallback? onTap}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StreakChipRow(streaks: streaks, onTap: onTap),
      ),
    ),
  );
}

void main() {
  testWidgets('renders nothing when there are no streaks (no goals set)', (tester) async {
    await _pump(tester, const []);

    expect(find.byType(Tooltip), findsNothing);
    expect(find.byIcon(Icons.local_fire_department), findsNothing);
  });

  testWidgets('renders one flame chip per streak, in order', (tester) async {
    await _pump(tester, [
      _streak(StreakMetric.calories, current: 5, todayMet: true),
      _streak(StreakMetric.steps, current: 0, todayMet: false),
      _streak(StreakMetric.water, current: 2, todayMet: false),
    ]);

    expect(find.byIcon(Icons.local_fire_department), findsNWidgets(3));
    expect(find.text('5'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('an inactive streak (current 0) shows the "not started" tooltip', (tester) async {
    await _pump(tester, [_streak(StreakMetric.water, current: 0, todayMet: false)]);

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, contains('No water streak yet'));
  });

  testWidgets('an active streak shows the day-count tooltip', (tester) async {
    await _pump(tester, [_streak(StreakMetric.calories, current: 7, todayMet: true)]);

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, '7-day calorie streak');
  });

  testWidgets('tapping the row invokes onTap when provided', (tester) async {
    var tapped = false;
    await _pump(
      tester,
      [_streak(StreakMetric.steps, current: 3, todayMet: true)],
      onTap: () => tapped = true,
    );

    await tester.tap(find.byType(StreakChipRow));
    expect(tapped, isTrue);
  });

  testWidgets('with no onTap, the row is not wrapped in an InkWell', (tester) async {
    await _pump(tester, [_streak(StreakMetric.steps, current: 3, todayMet: true)]);

    expect(find.byType(InkWell), findsNothing);
  });
}
