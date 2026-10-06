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

/// docs/84 Prompt 9: the OpenFoodFacts option in the add-food-to-meal sheet — the checkbox and the "From OpenFoodFacts"
/// group in the suggestion list. The sheet is built with a fake repository that answers when the test says so.

class _NoGoal extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

class _Call {
  _Call(this.text, this.lang) : completer = Completer<OffSearchResult>();
  final String text;
  final String lang;
  final Completer<OffSearchResult> completer;
}

class _FakeRepo implements OffSearchRepository {
  final calls = <_Call>[];

  @override
  Future<OffSearchResult> search(String text, String lang, {CancelToken? cancelToken}) {
    final call = _Call(text, lang);
    calls.add(call);
    return call.completer.future;
  }
}

class _FakePrefs implements OffSearchPreferences {
  _FakePrefs({this.stored = false});
  bool stored;

  @override
  Future<bool> isEnabled() async => stored;

  @override
  Future<void> setEnabled(bool enabled) async => stored = enabled;
}

Food _food(String id, String name) => Food(clientId: id, name: name, caloriesPer100g: 100, proteinPer100g: 10);

const _csirke = OffSearchItem(
  barcode: '4056489827702',
  name: 'Csirkemell',
  brand: 'Pikok',
  caloriesPer100g: 110,
  proteinPer100g: 14,
  carbsPer100g: 2.4,
  fatPer100g: 4.9,
);
const _noBrand = OffSearchItem(barcode: '5997000000001', name: 'Túró Rudi', caloriesPer100g: 400, proteinPer100g: 11);

OffSearchResult _answer(List<OffSearchItem> items, {OffSearchStatus status = OffSearchStatus.ok, bool fellBack = false}) =>
    OffSearchResult(status: status, language: 'en', fellBackToEnglish: fellBack, items: items);

/// Records what the sheet creates; nothing touches a database.
class _FakeFoodController extends FoodController {
  _FakeFoodController(this.created);
  final List<Map<String, Object?>> created;

  @override
  Stream<List<Food>> build() => Stream.value(const []);

  @override
  Future<Food> addFood({
    required String name,
    required double calories,
    required double protein,
    double? carbs,
    double? fat,
    String? barcode,
    bool hidden = false,
  }) async {
    created.add({'name': name, 'calories': calories, 'protein': protein, 'carbs': carbs, 'fat': fat, 'barcode': barcode, 'hidden': hidden});
    return Food(clientId: 'new-${created.length}', name: name, caloriesPer100g: calories, proteinPer100g: protein, carbsPer100g: carbs, fatPer100g: fat, barcode: barcode);
  }
}

late _FakeRepo _repo;
final _created = <Map<String, Object?>>[];

Future<void> _pump(WidgetTester tester,
    {bool stored = false, bool offline = false, Food? initialFood, double textScale = 1.0, List<Food>? foods}) async {
  _repo = _FakeRepo();
  _created.clear();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        foodSearchProvider.overrideWith((ref) => Stream.value(foods ?? [_food('chicken', 'Chicken'), _food('rice', 'Rice')])),
        foodControllerProvider.overrideWith(() => _FakeFoodController(_created)),
        foodUsageProvider.overrideWith((ref) => Stream.value(const {})),
        settingsControllerProvider.overrideWith(_NoGoal.new),
        mealsOnDayProvider.overrideWith((ref, day) => Stream.value(const <Meal>[])),
        offSearchRepositoryProvider.overrideWithValue(_repo),
        offSearchPreferencesProvider.overrideWithValue(_FakePrefs(stored: stored)),
        isOfflineProvider.overrideWith((ref) => Stream.value(offline)),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AddMealEntrySheet(initialFood: initialFood, initialGrams: initialFood == null ? null : 100)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _toggle() => find.byKey(const ValueKey('off-search-toggle'));
Finder _searchField() => find.byType(TextFormField).first;
Finder _sectionTitle() => find.byKey(const ValueKey('off-section-title'));

Future<void> _tick(WidgetTester tester) async {
  await tester.tap(_toggle());
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_searchField(), text);
  await tester.pump();
}

/// Past the 400 ms debounce, so the request is made.
Future<void> _debounce(WidgetTester tester) => tester.pump(offSearchDebounce + const Duration(milliseconds: 50));

Future<void> _answerLast(WidgetTester tester, OffSearchResult result) async {
  _repo.calls.last.completer.complete(result);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('the checkbox is above the search field, off by default; edit mode has no search and no checkbox', (tester) async {
    await _pump(tester);
    expect(_toggle(), findsOneWidget);
    expect(find.text('Search OpenFoodFacts too'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(_toggle()).value, isFalse);
    expect(tester.getTopLeft(_toggle()).dy, lessThan(tester.getTopLeft(_searchField()).dy)); // the list opens below the field and must not cover it

    await _pump(tester, initialFood: _food('chicken', 'Chicken'));
    expect(_toggle(), findsNothing);
  });

  testWidgets('the stored choice is applied when the sheet opens', (tester) async {
    await _pump(tester, stored: true);

    expect(tester.widget<CheckboxListTile>(_toggle()).value, isTrue);
  });

  testWidgets('box off: typing shows only the own suggestions and makes no request', (tester) async {
    await _pump(tester);

    await _type(tester, 'chick');
    await _debounce(tester);

    expect(find.text('Chicken'), findsOneWidget);
    expect(_sectionTitle(), findsNothing);
    expect(_repo.calls, isEmpty);
  });

  testWidgets('ticked: a request after the debounce with the cleaned text and the app language, then the group under the own rows',
      (tester) async {
    await _pump(tester);
    await _tick(tester);

    await _type(tester, 'Chick');
    expect(_repo.calls, isEmpty); // not yet: the debounce
    await _debounce(tester);
    expect(_repo.calls.single.text, 'chick');
    expect(_repo.calls.single.lang, 'en');
    expect(find.text('Searching OpenFoodFacts…'), findsOneWidget);

    await _answerLast(tester, _answer([_csirke, _noBrand]));

    expect(_sectionTitle(), findsOneWidget);
    expect(find.text('FROM OPENFOODFACTS'), findsOneWidget);
    expect(find.textContaining('Csirkemell'), findsOneWidget);
    expect(find.text('Pikok'), findsOneWidget); // the brand
    expect(find.text('OpenFoodFacts'), findsOneWidget); // no brand: the source instead
    expect(find.text('OFF'), findsNWidgets(0)); // the tag sits inside the name's rich text, asserted below
    expect(find.textContaining('OFF', findRichText: true), findsWidgets);
    expect(find.text('110 kcal'), findsOneWidget);
    expect(find.text('Searching OpenFoodFacts…'), findsNothing);
    // the own row stays above the group
    expect(tester.getTopLeft(find.text('Chicken')).dy, lessThan(tester.getTopLeft(_sectionTitle()).dy));
    expect(tester.getTopLeft(_sectionTitle()).dy, lessThan(tester.getTopLeft(find.textContaining('Csirkemell')).dy));
  });

  testWidgets('no own match, but OpenFoodFacts has some: the list still opens', (tester) async {
    await _pump(tester);
    await _tick(tester);

    await _type(tester, 'csirkemell');
    await _debounce(tester);
    await _answerLast(tester, _answer([_csirke]));

    expect(find.text('Chicken'), findsNothing);
    expect(_sectionTitle(), findsOneWidget);
    expect(find.textContaining('Csirkemell'), findsOneWidget);
  });

  testWidgets('the English fallback, unavailable and rate-limited each get their one line', (tester) async {
    await _pump(tester);
    await _tick(tester);

    await _type(tester, 'pumpkin');
    await _debounce(tester);
    await _answerLast(tester, _answer([_csirke], fellBack: true));
    expect(find.text('Nothing found among products sold in Hungary — showing English-language results from everywhere.'), findsOneWidget);

    await _type(tester, 'pumpkins');
    await _debounce(tester);
    await _answerLast(tester, _answer(const [], status: OffSearchStatus.unavailable));
    expect(find.text("OpenFoodFacts isn't answering right now."), findsOneWidget);

    await _type(tester, 'pumpkinss');
    await _debounce(tester);
    await _answerLast(tester, _answer(const [], status: OffSearchStatus.rateLimited));
    expect(find.text('Too many searches — try again in a minute.'), findsOneWidget);
  });

  testWidgets('a failed request reads as unavailable', (tester) async {
    await _pump(tester);
    await _tick(tester);

    await _type(tester, 'pumpkin');
    await _debounce(tester);
    _repo.calls.last.completer.completeError(DioException(
      requestOptions: RequestOptions(path: '/foods/off-search'),
      type: DioExceptionType.connectionError,
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text("OpenFoodFacts isn't answering right now."), findsOneWidget);
  });

  testWidgets('an empty answer says nothing was found', (tester) async {
    await _pump(tester);
    await _tick(tester);

    await _type(tester, 'pumpkin');
    await _debounce(tester);
    await _answerLast(tester, _answer(const []));

    expect(find.text('Nothing found on OpenFoodFacts.'), findsOneWidget);
  });

  testWidgets('under three letters the group asks for more and nothing is requested', (tester) async {
    await _pump(tester);
    await _tick(tester);

    await _type(tester, 'ch');
    await _debounce(tester);

    expect(find.text('Type at least 3 letters to search OpenFoodFacts.'), findsOneWidget);
    expect(_repo.calls, isEmpty);
  });

  testWidgets('ticking after typing searches what is already there; unticking removes the group', (tester) async {
    await _pump(tester);
    await _type(tester, 'pumpkin');
    await _debounce(tester);
    expect(_repo.calls, isEmpty);

    await _tick(tester);
    await _debounce(tester);
    expect(_repo.calls.single.text, 'pumpkin');
    await _answerLast(tester, _answer([_csirke]));
    expect(_sectionTitle(), findsOneWidget);

    await _tick(tester); // off again
    await tester.pump();
    expect(_sectionTitle(), findsNothing);
  });

  testWidgets('offline the checkbox is disabled and says why, and the sheet works as before', (tester) async {
    await _pump(tester, offline: true);

    expect(tester.widget<CheckboxListTile>(_toggle()).onChanged, isNull);
    expect(find.text("You're offline — OpenFoodFacts search needs a connection."), findsOneWidget);

    await _type(tester, 'chick');
    await tester.pumpAndSettle();
    expect(find.text('Chicken'), findsOneWidget);
    expect(_repo.calls, isEmpty);
  });

  testWidgets('at 1.3x text size and on a small phone nothing overflows, with a long fallback note and brand', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _pump(tester, textScale: 1.3);
    await _tick(tester);

    await _type(tester, 'pumpkin');
    await _debounce(tester);
    await _answerLast(
      tester,
      _answer(
        [_csirke, const OffSearchItem(barcode: '9', name: 'Very long product name that has to wrap onto a second line somewhere', brand: 'A brand with a rather long name too', caloriesPer100g: 123, proteinPer100g: 1)],
        fellBack: true,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(_sectionTitle(), findsOneWidget);
  });

  group('picking an OpenFoodFacts row (Prompt 10)', () {
    Future<void> openFoundRows(WidgetTester tester, {List<Food>? foods, List<OffSearchItem> items = const [_csirke]}) async {
      await _pump(tester, foods: foods);
      await _tick(tester);
      await _type(tester, 'csirkemell');
      await _debounce(tester);
      await _answerLast(tester, _answer(items));
    }

    testWidgets('creates the food through the food controller and picks it: name in the field, quantity card shown', (tester) async {
      await openFoundRows(tester);

      await tester.tap(find.textContaining('Csirkemell'));
      await tester.pumpAndSettle();

      expect(_created, hasLength(1));
      expect(_created.single, {
        'name': 'Csirkemell',
        'calories': 110.0,
        'protein': 14.0,
        'carbs': 2.4,
        'fat': 4.9,
        'barcode': '4056489827702',
        'hidden': false,
      });
      expect(tester.widget<TextFormField>(_searchField()).controller!.text, 'Csirkemell');
      expect(find.byKey(const Key('quantityField')), findsOneWidget);
      expect(_sectionTitle(), findsNothing); // the list is closed
    });

    testWidgets('a missing carbs or fat stays null — nothing is invented', (tester) async {
      await openFoundRows(tester, items: [_noBrand]);

      await tester.tap(find.textContaining('Túró Rudi'));
      await tester.pumpAndSettle();

      expect(_created.single['carbs'], isNull);
      expect(_created.single['fat'], isNull);
    });

    testWidgets('a food the user already has for that barcode is picked, and nothing is created', (tester) async {
      const mine = Food(clientId: 'mine', name: 'My chicken', caloriesPer100g: 100, proteinPer100g: 10, barcode: '4056489827702');
      await openFoundRows(tester, foods: [mine]);

      await tester.tap(find.textContaining('Csirkemell'));
      await tester.pumpAndSettle();

      expect(_created, isEmpty);
      expect(tester.widget<TextFormField>(_searchField()).controller!.text, 'My chicken');
      expect(find.byKey(const Key('quantityField')), findsOneWidget);
    });

    testWidgets('a name already used by another food is created as "Name (Brand)"', (tester) async {
      await openFoundRows(tester, foods: [_food('n', 'Csirkemell')]);

      await tester.tap(find.textContaining('Csirkemell').last);
      await tester.pumpAndSettle();

      expect(_created.single['name'], 'Csirkemell (Pikok)');
      expect(tester.widget<TextFormField>(_searchField()).controller!.text, 'Csirkemell (Pikok)');
    });

    testWidgets('tapping the same row twice quickly creates one food', (tester) async {
      await openFoundRows(tester);

      final row = find.text('Pikok'); // the brand line is unique to the row (the name also matches the typed text)
      await tester.tap(row);
      await tester.tap(row, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(_created, hasLength(1));
    });
  });

  testWidgets('picking an own suggestion still works with the option ticked', (tester) async {
    await _pump(tester);
    await _tick(tester);
    await _type(tester, 'chick');
    await _debounce(tester);
    await _answerLast(tester, _answer([_csirke]));

    await tester.tap(find.text('Chicken'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quantityField')), findsOneWidget);
  });
}
