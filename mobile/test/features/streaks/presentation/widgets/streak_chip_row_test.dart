import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';
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

Future<void> _pump(
  WidgetTester tester,
  List<Streak> streaks, {
  VoidCallback? onTap,
  Locale locale = const Locale('en'),
  double textScale = 1,
  double width = 411,
}) {
  return tester.pumpWidget(
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
        body: Center(
          child: SizedBox(
            width: width - 40,
            child: StreakChipRow(streaks: streaks, onTap: onTap),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders nothing when there are no streaks (no goals set)', (tester) async {
    await _pump(tester, const []);

    expect(find.byType(Tooltip), findsNothing);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);
  });

  testWidgets('renders one icon + count per streak, in order, each metric with its own icon',
      (tester) async {
    await _pump(tester, [
      _streak(StreakMetric.calories, current: 5, todayMet: true),
      _streak(StreakMetric.steps, current: 0, todayMet: false),
      _streak(StreakMetric.water, current: 2, todayMet: false),
      _streak(StreakMetric.workout, current: 6, todayMet: true),
    ]);

    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    expect(find.byIcon(Icons.directions_walk_rounded), findsOneWidget);
    expect(find.byIcon(Icons.water_drop_rounded), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    // Left to right, in the given order.
    final xs = [
      Icons.local_fire_department_rounded,
      Icons.directions_walk_rounded,
      Icons.water_drop_rounded,
      Icons.fitness_center_rounded,
    ].map((i) => tester.getCenter(find.byIcon(i)).dx).toList();
    expect(xs, [...xs]..sort());
  });

  testWidgets('a streak at zero is muted, an active one takes its metric colour', (tester) async {
    await _pump(tester, [
      _streak(StreakMetric.calories, current: 14, todayMet: true),
      _streak(StreakMetric.water, current: 0, todayMet: false),
    ]);

    Color colorOf(IconData icon) => tester.widget<Icon>(find.byIcon(icon)).color!;
    expect(colorOf(Icons.local_fire_department_rounded), AppMetricColors.dark.calories);
    expect(colorOf(Icons.water_drop_rounded), AppPalette.dark.text3);
  });

  testWidgets('shows the "Week in review" label only when it can be tapped', (tester) async {
    await _pump(tester, [_streak(StreakMetric.workout, current: 1, todayMet: true)]);
    expect(find.text('Week in review'), findsNothing);

    await _pump(tester, [_streak(StreakMetric.workout, current: 1, todayMet: true)], onTap: () {});
    expect(find.text('Week in review'), findsOneWidget);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('Hungarian, four streaks, 360 dp wide, ×$scale: no overflow, label not cut off',
        (tester) async {
      await _pump(
        tester,
        [
          _streak(StreakMetric.calories, current: 14, todayMet: true),
          _streak(StreakMetric.steps, current: 3, todayMet: false),
          _streak(StreakMetric.water, current: 0, todayMet: false),
          _streak(StreakMetric.workout, current: 6, todayMet: true),
        ],
        onTap: () {},
        locale: const Locale('hu'),
        textScale: scale,
        width: 360,
      );
      expect(find.text('Heti összefoglaló'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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
