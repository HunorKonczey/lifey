import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/sync/connectivity_status_provider.dart';
import 'package:lifey/features/nutrition/application/food_controller.dart';
import 'package:lifey/features/nutrition/application/food_usage_provider.dart';
import 'package:lifey/features/nutrition/application/selected_meal_day_provider.dart';
import 'package:lifey/features/nutrition/data/off_search_preferences.dart';
import 'package:lifey/features/nutrition/data/off_search_repository.dart';
import 'package:lifey/features/nutrition/domain/food.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/nutrition/domain/off_search.dart';
import 'package:lifey/features/nutrition/presentation/widgets/add_meal_entry_sheet.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// LIF-133: the add-food-to-meal sheet as the app shows it - a modal bottom sheet - with the OpenFoodFacts option ticked
/// and results listed. The suggestion list is an overlay under the search field; it has to stay a usable size and must
/// not sit on top of, or push off the screen, the "Add to meal" button - with the keyboard up and without it, at 1.0x and
/// 1.3x text, on a tall phone and on a small one.

class _NoGoal extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

class _FakeRepo implements OffSearchRepository {
  @override
  Future<OffSearchResult> search(String text, String lang, {CancelToken? cancelToken}) async => OffSearchResult(
        status: OffSearchStatus.ok,
        language: 'en',
        fellBackToEnglish: false,
        items: [
          for (var i = 0; i < 8; i++)
            OffSearchItem(
              barcode: '599700000000$i',
              name: 'Csirkemell $i',
              brand: 'Márka $i',
              caloriesPer100g: 110 + i.toDouble(),
              proteinPer100g: 14,
              carbsPer100g: 2.4,
              fatPer100g: 4.9,
            ),
        ],
      );
}

class _FakePrefs implements OffSearchPreferences {
  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<void> setEnabled(bool enabled) async {}
}

class _FakeFoodController extends FoodController {
  @override
  Stream<List<Food>> build() => Stream.value(const []);
}

Food _food(String id, String name) => Food(clientId: id, name: name, caloriesPer100g: 100, proteinPer100g: 10);

Future<void> _open(WidgetTester tester, {required Size size, double textScale = 1.0, double keyboard = 0}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 2);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        foodSearchProvider.overrideWith((ref) => Stream.value([_food('chicken', 'Chicken'), _food('rice', 'Rice')])),
        foodControllerProvider.overrideWith(_FakeFoodController.new),
        foodUsageProvider.overrideWith((ref) => Stream.value(const {})),
        settingsControllerProvider.overrideWith(_NoGoal.new),
        mealsOnDayProvider.overrideWith((ref, day) => Stream.value(const <Meal>[])),
        offSearchRepositoryProvider.overrideWithValue(_FakeRepo()),
        offSearchPreferencesProvider.overrideWithValue(_FakePrefs()),
        isOfflineProvider.overrideWith((ref) => Stream.value(false)),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  useRootNavigator: true,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => const AddMealEntrySheet(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, 'csirke');
  await tester.pump(offSearchDebounce + const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

/// The suggestion list's outer box: the Material that holds the rows (the one containing the OpenFoodFacts title).
Rect _listRect(WidgetTester tester) {
  final material = find.ancestor(of: find.byKey(const ValueKey('off-section-title')), matching: find.byType(Material)).first;
  return tester.getRect(material);
}

Rect _buttonRect(WidgetTester tester) => tester.getRect(find.byType(FilledButton));

void main() {
  // Pixel 10-like (412 x 915 dp) and a small phone (360 x 640 dp); each with and without the keyboard, at 1.0x / 1.3x text.
  final cases = <({String name, Size size, double scale, double keyboard})>[
    (name: 'tall phone, no keyboard', size: const Size(412, 915), scale: 1.0, keyboard: 0),
    (name: 'tall phone, no keyboard, 1.3x text', size: const Size(412, 915), scale: 1.3, keyboard: 0),
    (name: 'tall phone, keyboard up', size: const Size(412, 915), scale: 1.0, keyboard: 300),
    (name: 'small phone, no keyboard', size: const Size(360, 640), scale: 1.0, keyboard: 0),
    (name: 'small phone, no keyboard, 1.3x text', size: const Size(360, 640), scale: 1.3, keyboard: 0),
  ];
  for (final c in cases) {
    testWidgets('${c.name}: the list shows at least three rows and sits above a fully visible "Add to meal"', (tester) async {
      await _open(tester, size: c.size, textScale: c.scale, keyboard: c.keyboard);

      final list = _listRect(tester);
      final button = _buttonRect(tester);
      // ignore: avoid_print
      print('${c.name}: list ${list.top.round()}..${list.bottom.round()} (${list.height.round()} high), button ${button.top.round()}..${button.bottom.round()}, screen ${c.size.height - c.keyboard}');

      final visibleBottom = c.size.height - c.keyboard;
      expect(button.bottom, lessThanOrEqualTo(visibleBottom + 0.5), reason: 'the button is on screen');
      expect(list.bottom, lessThanOrEqualTo(button.top + 0.5), reason: 'the list does not cover the button');
      expect(list.height, greaterThanOrEqualTo(3 * 48.0), reason: 'room for at least three rows');
    });
  }
}
