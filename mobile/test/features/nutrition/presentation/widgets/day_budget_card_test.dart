import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/format/lifey_format.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/nutrition/domain/daily_macros.dart';
import 'package:lifey/features/nutrition/presentation/widgets/day_budget_card.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/metric_bar.dart';
import 'package:lifey/shared/widgets/ds/tinted_chip.dart';

UserSettings _settings({int? kcal = 2360, int? protein = 129, int? carbs = 313, int? fat = 66}) =>
    const UserSettings.defaults().copyWith(
      dailyCalorieGoal: kcal,
      dailyProteinGoal: protein,
      dailyCarbsGoal: carbs,
      dailyFatGoal: fat,
    );

final _today = DailyMacros(day: DateTime(2026, 9, 24), calories: 621, protein: 29, carbs: 88, fat: 20);

Future<void> _pump(
  WidgetTester tester,
  DailyMacros? totals,
  UserSettings settings, {
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
        body: Padding(padding: const EdgeInsets.all(20), child: DayBudgetCard(totals: totals, settings: settings)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// All text on screen, plain and rich, joined.
String _text(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join('|');

void main() {
  testWidgets('canvas day: 621 / 2,360 kcal, 1,739 left, macros against their goals', (tester) async {
    await _pump(tester, _today, _settings());

    final all = _text(tester);
    expect(all, contains('621'));
    expect(all, contains('/ 2,360 kcal'));
    expect(find.text('1,739 left'), findsOneWidget);
    expect(all, contains('29 / 129 g P'));
    expect(all, contains('88 / 313 g C'));
    expect(all, contains('20 / 66 g F'));
  });

  testWidgets('the bar splits the calorie goal: protein and carbs 4 kcal/g, fat 9', (tester) async {
    await _pump(tester, _today, _settings());

    final bar = tester.widget<RatioBar>(find.byType(RatioBar));
    expect(bar.total, 2360);
    expect(bar.segments.map((s) => s.value), [29 * 4, 88 * 4, 20 * 9]);
    // 116 / 352 / 180 of 2 360 → 5 % / 15 % / 8 % of the width, as drawn.
    final fractions = RatioBar.fractions([for (final s in bar.segments) s.value], bar.total);
    expect(fractions[0], closeTo(0.049, 0.001));
    expect(fractions[1], closeTo(0.149, 0.001));
    expect(fractions[2], closeTo(0.076, 0.001));
  });

  testWidgets('over the goal the chip says how much and turns into "over"', (tester) async {
    await _pump(
      tester,
      DailyMacros(day: DateTime(2026, 9, 24), calories: 2572, protein: 100, carbs: 300, fat: 90),
      _settings(),
    );

    expect(find.text('212 over'), findsOneWidget);
    expect(find.textContaining('left'), findsNothing);
  });

  testWidgets('a day without meals reads zero against the full goal', (tester) async {
    await _pump(tester, null, _settings());

    expect(find.text('2,360 left'), findsOneWidget);
    expect(_text(tester), contains('0 / 129 g P'));
  });

  testWidgets('no calorie goal: no chip, plain "kcal", the bar shows the macros share', (tester) async {
    await _pump(tester, _today, _settings(kcal: null));

    expect(find.byType(TintedChip), findsNothing);
    expect(_text(tester), contains(' kcal'));
    expect(tester.widget<RatioBar>(find.byType(RatioBar)).total, isNull);
  });

  testWidgets('a macro without a goal shows just its grams', (tester) async {
    await _pump(tester, _today, _settings(protein: null));

    final all = _text(tester);
    expect(all, contains('29 g P'));
    expect(all, isNot(contains('/ 129 g P')));
    expect(all, contains('88 / 313 g C'));
  });

  testWidgets('Hungarian: grouped with a no-break space, "maradt", F / Sz / Zs letters', (tester) async {
    await _pump(tester, _today, _settings(), locale: const Locale('hu'));

    final f = LifeyFormat('hu');
    expect(find.text('${f.integer(1739)} maradt'), findsOneWidget);
    final all = _text(tester);
    expect(all, contains('29 / 129 g F'));
    expect(all, contains('88 / 313 g Sz'));
    expect(all, contains('20 / 66 g Zs'));
  });

  for (final width in [411.0, 360.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('no overflow at ${width.toInt()} dp, text ×$scale, HU, light', (tester) async {
        await _pump(
          tester,
          _today,
          _settings(),
          locale: const Locale('hu'),
          width: width,
          textScale: scale,
          theme: AppTheme.light,
        );

        expect(tester.takeException(), isNull);
      });
    }
  }
}
