import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/nutrition/application/daily_macros_controller.dart';
import 'package:lifey/features/nutrition/domain/daily_macros.dart';
import 'package:lifey/features/nutrition/presentation/macros_tab.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/metric_bar.dart';
import 'package:lifey/shared/widgets/ds/progress_ring.dart';

class _Goals extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults().copyWith(
        dailyCalorieGoal: 2360,
        dailyProteinGoal: 129,
        dailyCarbsGoal: 313,
        dailyFatGoal: 66,
      ));
}

class _NoGoals extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

DateTime _day(int back) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day - back);
}

DailyMacros _macros(int back, double kcal, double p, double c, double f) =>
    DailyMacros(day: _day(back), calories: kcal, protein: p, carbs: c, fat: f);

final _canvasWeek = [
  _macros(0, 621, 29, 88, 20),
  _macros(1, 1765, 104, 188, 58),
  _macros(2, 2010, 118, 221, 71),
  _macros(3, 1820, 97, 205, 55),
];

Future<void> _pump(
  WidgetTester tester,
  List<DailyMacros> days, {
  bool goals = true,
  Locale locale = const Locale('en'),
  double textScale = 1,
  double width = 411,
  ThemeData? theme,
  DateTime? cutoff,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dailyMacrosProvider.overrideWith((ref) => Stream.value(days)),
        settingsControllerProvider.overrideWith(goals ? _Goals.new : _NoGoals.new),
        historyCutoffProvider.overrideWithValue(cutoff),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: MacrosTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _allText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join('|');

void main() {
  testWidgets("today: big kcal / goal, the share of the goal and three rings against their goals", (tester) async {
    await _pump(tester, _canvasWeek);

    final all = _allText(tester);
    expect(all, contains('621'));
    expect(all, contains('/ 2,360 kcal'));
    expect(find.text('26%'), findsOneWidget); // 621 / 2 360
    final rings = tester.widgetList<ProgressRing>(find.byType(ProgressRing)).toList();
    expect(rings, hasLength(3));
    expect(rings[0].progress, closeTo(29 / 129, 1e-9));
    expect(rings[1].progress, closeTo(88 / 313, 1e-9));
    expect(rings[2].progress, closeTo(20 / 66, 1e-9));
    for (final text in ['29', '/ 129 g', '88', '/ 313 g', '20', '/ 66 g', 'Protein', 'Carbs', 'Fat']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('LAST 7 DAYS: a row per earlier day with kcal and P / C / F grams', (tester) async {
    await _pump(tester, _canvasWeek);

    expect(find.text('LAST 7 DAYS'), findsOneWidget);
    expect(find.text('1,765'), findsNothing); // kcal is a rich span with its unit
    final all = _allText(tester);
    expect(all, contains('1,765'));
    expect(all, contains('2,010'));
    expect(find.text('P 104'), findsOneWidget);
    expect(find.text('C 188'), findsOneWidget);
    expect(find.text('F 58'), findsOneWidget);
    expect(find.byType(RatioBar), findsNWidgets(3)); // yesterday, 2 and 3 days ago
  });

  testWidgets("each day's bar adds up to the whole: the segments split it 100 %", (tester) async {
    await _pump(tester, _canvasWeek);

    for (final bar in tester.widgetList<RatioBar>(find.byType(RatioBar))) {
      expect(bar.total, isNull);
      final fractions = RatioBar.fractions([for (final s in bar.segments) s.value], bar.total);
      expect(fractions.fold<double>(0, (a, b) => a + b), closeTo(1, 1e-9));
    }
  });

  testWidgets('a ring over its goal runs a second lap', (tester) async {
    await _pump(tester, [_macros(0, 2500, 160, 300, 70)]);

    final rings = tester.widgetList<ProgressRing>(find.byType(ProgressRing)).toList();
    expect(rings[0].progress, greaterThan(1)); // 160 / 129
    expect(ringSweeps(rings[0].progress).overflow, greaterThan(0));
    expect(rings[1].progress, lessThan(1));
  });

  testWidgets('earlier days only reach back a week', (tester) async {
    await _pump(tester, [..._canvasWeek, _macros(7, 1500, 80, 150, 50), _macros(8, 1400, 70, 140, 45)]);

    expect(find.text('P 80'), findsOneWidget);
    expect(find.text('P 70'), findsNothing);
  });

  testWidgets('no meal today: the card reads zero, earlier days still list', (tester) async {
    await _pump(tester, [_macros(1, 1765, 104, 188, 58)]);

    expect(find.text('0%'), findsOneWidget);
    expect(find.text('P 104'), findsOneWidget);
  });

  testWidgets('no goals: rings stay empty and show only the grams, no share chip', (tester) async {
    await _pump(tester, _canvasWeek, goals: false);

    for (final ring in tester.widgetList<ProgressRing>(find.byType(ProgressRing))) {
      expect(ring.progress, 0);
    }
    expect(find.text('26%'), findsNothing);
    expect(_allText(tester), contains(' kcal'));
  });

  testWidgets('no data at all shows the empty state', (tester) async {
    await _pump(tester, const []);

    expect(find.byType(ProgressRing), findsNothing);
    expect(find.text('No macros logged yet'), findsOneWidget);
  });

  testWidgets('Hungarian letters and section label', (tester) async {
    await _pump(tester, _canvasWeek, locale: const Locale('hu'));

    expect(find.text('UTOLSÓ 7 NAP'), findsOneWidget);
    expect(find.text('F 104'), findsOneWidget);
    expect(find.text('Sz 188'), findsOneWidget);
    expect(find.text('Zs 58'), findsOneWidget);
  });

  for (final width in [411.0, 360.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('no overflow at ${width.toInt()} dp, text x$scale, HU, light', (tester) async {
        await _pump(tester, _canvasWeek, locale: const Locale('hu'), width: width, textScale: scale, theme: AppTheme.light);

        expect(tester.takeException(), isNull);
      });
    }
  }
}
