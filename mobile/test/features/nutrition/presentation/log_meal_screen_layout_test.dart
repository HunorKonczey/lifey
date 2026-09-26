import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/ads/interstitial_manager.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/sync/connectivity_status_provider.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/nutrition/application/meal_controller.dart';
import 'package:lifey/features/nutrition/application/selected_meal_day_provider.dart';
import 'package:lifey/features/nutrition/data/meal_repository.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/nutrition/presentation/log_meal_screen.dart';
import 'package:lifey/features/nutrition/presentation/widgets/meal_summary_panel.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/l10n/app_localizations.dart';

class _FakeMealController extends MealController {
  final updates = <List<MealEntryInput>>[];

  @override
  Stream<List<Meal>> build() => Stream.value(const []);

  @override
  Future<String> logMeal({
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
    String? name,
  }) async =>
      'new-meal';

  @override
  Future<void> updateMeal(
    String clientId, {
    required DateTime dateTime,
    required MealType mealType,
    required List<MealEntryInput> entries,
    String? name,
  }) async {
    updates.add(entries);
  }
}

class _FakeSettings extends SettingsController {
  @override
  Stream<UserSettings> build() =>
      Stream.value(const UserSettings.defaults().copyWith(dailyCalorieGoal: 2360));
}

class _FakeSettingsNoGoal extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

class _NoAds extends InterstitialManager {
  _NoAds(super.ref);

  @override
  Future<void> maybeShow(BuildContext context, InterstitialReason reason) async {}
}

MealEntry _entry(String name, double grams, double kcal, double protein) => MealEntry(
      foodClientId: name,
      foodName: name,
      quantityInGrams: grams,
      calories: kcal,
      protein: protein,
      carbs: kcal / 8,
      fat: kcal / 30,
    );

final _now = DateTime.now();
final _at = DateTime(_now.year, _now.month, _now.day, 7, 15);

final _breakfast = Meal(
  clientId: 'breakfast',
  dateTime: _at,
  mealType: MealType.breakfast,
  entries: [
    _entry('Rolled oats', 60, 227, 8),
    _entry('Greek yogurt 2%', 150, 110, 15),
    _entry('Blueberries', 80, 46, 1),
  ],
);

final _snack = Meal(
  clientId: 'snack',
  dateTime: DateTime(_now.year, _now.month, _now.day, 8, 27),
  mealType: MealType.snack,
  entries: [_entry('Apple', 182, 238, 1)],
);

Future<_FakeMealController> _pump(
  WidgetTester tester, {
  Meal? meal,
  DateTime? initialDate,
  Locale locale = const Locale('en'),
  double textScale = 1,
  double width = 411,
  ThemeData? theme,
  int? goal = 2360,
}) async {
  tester.view.physicalSize = Size(width * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final controller = _FakeMealController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mealControllerProvider.overrideWith(() => controller),
        settingsControllerProvider.overrideWith(goal == null ? _FakeSettingsNoGoal.new : _FakeSettings.new),
        mealsOnDayProvider.overrideWith((ref, day) => Stream.value([_breakfast, _snack])),
        interstitialManagerProvider.overrideWith(_NoAds.new),
        isOfflineProvider.overrideWith((ref) => Stream.value(false)),
        aiCreditsProvider.overrideWithValue(null),
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
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => LogMealScreen(meal: meal, initialDate: initialDate)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('edit layout: Save in the header, type chips, date row, food rows, three actions', (tester) async {
    await _pump(tester, meal: _breakfast);

    expect(find.text('Edit meal'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    for (final type in ['Breakfast', 'Lunch', 'Dinner', 'Snack']) {
      expect(find.widgetWithText(ChoiceChip, type), findsOneWidget, reason: type);
    }
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Breakfast')).selected, isTrue);
    expect(find.textContaining('07:15'), findsOneWidget);
    expect(find.text('FOODS · 3'), findsOneWidget);
    expect(find.text('Rolled oats'), findsOneWidget);
    expect(find.text('60 g · 8 g protein'), findsOneWidget);
    expect(find.textContaining('227'), findsOneWidget);
    expect(find.text('Add food'), findsOneWidget);
    expect(find.text('Macros only'), findsOneWidget);
    expect(find.text('From photo'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsNWidgets(3));
  });

  testWidgets('the summary shows the meal total and "today after this meal" without counting the meal twice', (tester) async {
    await _pump(tester, meal: _breakfast);

    final panel = tester.widget<MealSummaryPanel>(find.byType(MealSummaryPanel));
    expect(panel.calories, 383);
    expect(panel.preview!.othersKcal, 238); // the snack; the saved breakfast is left out
    expect(find.text('Meal total'), findsOneWidget);
    expect(find.text('383'), findsOneWidget);
    expect(find.text('Today after this meal'), findsOneWidget);
    expect(find.text('1,739 kcal left'), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget);
  });

  testWidgets('removing a food from its ⋮ menu updates the list, the total and what is left', (tester) async {
    final controller = await _pump(tester, meal: _breakfast);

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('FOODS · 2'), findsOneWidget);
    expect(find.text('Rolled oats'), findsNothing);
    expect(find.text('156'), findsOneWidget); // 110 + 46
    expect(find.text('1,966 kcal left'), findsOneWidget); // 2 360 − 238 − 156
    expect(controller.updates.last.length, 2); // autosaved
  });

  testWidgets('a meal for an earlier day names that day in the preview', (tester) async {
    final earlier = Meal(
      clientId: 'old',
      dateTime: DateTime(_now.year, _now.month, _now.day - 2, 13),
      mealType: MealType.lunch,
      entries: [_entry('Pasta', 200, 300, 10)],
    );
    await _pump(tester, meal: earlier);

    expect(find.text('Today after this meal'), findsNothing);
    expect(find.textContaining('after this meal'), findsOneWidget);
  });

  testWidgets('no calorie goal: just the meal total, no "left" line', (tester) async {
    await _pump(tester, meal: _breakfast, goal: null);

    expect(find.text('Meal total'), findsOneWidget);
    expect(find.textContaining('after this meal'), findsNothing);
  });

  testWidgets('a new meal has no food rows and no summary yet', (tester) async {
    await _pump(tester);

    expect(find.text('Log meal'), findsOneWidget);
    expect(find.textContaining('FOODS'), findsNothing);
    expect(find.byType(MealSummaryPanel), findsNothing);
    expect(find.text('Add food'), findsOneWidget);
  });

  testWidgets('a new meal starts on the picked day at the current time of day', (tester) async {
    final day = DateTime(_now.year, _now.month, _now.day - 3);
    await _pump(tester, initialDate: day);

    final expectedDay = '${day.day}';
    expect(find.textContaining(expectedDay), findsWidgets);
  });

  testWidgets('Save closes the screen', (tester) async {
    await _pump(tester, meal: _breakfast);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(LogMealScreen), findsNothing);
  });

  for (final width in [411.0, 360.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('no overflow at ${width.toInt()} dp, text x$scale, HU, light', (tester) async {
        await _pump(tester, meal: _breakfast, locale: const Locale('hu'), width: width, textScale: scale, theme: AppTheme.light);

        expect(tester.takeException(), isNull);
        expect(find.text('Étkezés szerkesztése'), findsOneWidget);
      });
    }
  }
}
