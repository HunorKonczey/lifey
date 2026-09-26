import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/sync/sync_status_provider.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/nutrition/presentation/widgets/meal_list_row.dart';
import 'package:lifey/l10n/app_localizations.dart';

MealEntry _entry(String name, double kcal, {double p = 0, double c = 0, double f = 0}) => MealEntry(
      foodClientId: name,
      foodName: name,
      quantityInGrams: 100,
      calories: kcal,
      protein: p,
      carbs: c,
      fat: f,
    );

Meal _meal({String? name, MealType type = MealType.breakfast, List<MealEntry>? entries}) => Meal(
      clientId: 'm1',
      dateTime: DateTime(2026, 9, 24, 7, 15),
      mealType: type,
      name: name,
      entries: entries ??
          [
            _entry('Rolled oats', 227, p: 8, c: 40, f: 4),
            _entry('Greek yogurt 2%', 110, p: 15, c: 6, f: 2),
            _entry('Blueberries', 46, p: 1, c: 12, f: 1),
          ],
    );

Future<void> _pump(
  WidgetTester tester,
  Meal meal, {
  Locale locale = const Locale('en'),
  double textScale = 1,
  double width = 411,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [syncStatusByClientIdProvider.overrideWithValue(const {})],
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: MealListRow(meal: meal, onTap: onTap ?? () {}, onLongPress: onLongPress ?? () {}),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a named meal: name, "Breakfast · 07:15", kcal, P / C / F, foods', (tester) async {
    await _pump(tester, _meal(name: 'Oats & berries'));

    expect(find.text('Oats & berries'), findsOneWidget);
    expect(find.text('Breakfast · 07:15'), findsOneWidget);
    expect(find.textContaining('383'), findsOneWidget); // 227 + 110 + 46
    expect(find.text('P 24'), findsOneWidget);
    expect(find.text('C 58'), findsOneWidget);
    expect(find.text('F 7'), findsOneWidget);
    expect(find.text('Rolled oats, Greek yogurt 2%, Blueberries'), findsOneWidget);
  });

  testWidgets('an unnamed meal is titled by its type and the meta line is just the time', (tester) async {
    await _pump(
      tester,
      _meal(type: MealType.snack, entries: [_entry('Apple', 95, c: 25), _entry('Almonds', 143, p: 6, f: 13)]),
    );

    expect(find.text('Snack'), findsOneWidget);
    expect(find.text('07:15'), findsOneWidget);
    expect(find.text('Apple, Almonds'), findsOneWidget);
  });

  testWidgets('a long foods line wraps to two lines instead of being cut to "Bluebe…"', (tester) async {
    final foods = [
      for (final n in ['Rolled oats', 'Greek yogurt 2%', 'Blueberries', 'Chia seeds', 'Honey', 'Almond milk'])
        _entry(n, 50),
    ];
    await _pump(tester, _meal(entries: foods), width: 360);

    final finder = find.textContaining('Rolled oats, Greek');
    expect(tester.widget<Text>(finder).maxLines, 2);
    expect(tester.getSize(finder).height, lessThanOrEqualTo(2 * 13 * 1.4 + 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap and long-press reach the callbacks', (tester) async {
    var taps = 0;
    var longs = 0;
    await _pump(tester, _meal(), onTap: () => taps++, onLongPress: () => longs++);

    await tester.tap(find.text('Breakfast'));
    await tester.longPress(find.text('Breakfast'));

    expect(taps, 1);
    expect(longs, 1);
  });

  for (final width in [411.0, 360.0]) {
    testWidgets('no overflow at ${width.toInt()} dp, text x1.3, HU', (tester) async {
      await _pump(
        tester,
        _meal(name: 'Zabkása áfonyával és görög joghurttal'),
        width: width,
        textScale: 1.3,
        locale: const Locale('hu'),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('F 24'), findsOneWidget); // fehérje
    });
  }
}
