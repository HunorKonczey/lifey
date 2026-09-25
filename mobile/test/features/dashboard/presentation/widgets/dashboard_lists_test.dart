import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/dashboard/domain/recent_workout.dart';
import 'package:lifey/features/dashboard/domain/today_meal_group.dart';
import 'package:lifey/features/dashboard/presentation/widgets/recent_workouts_section.dart';
import 'package:lifey/features/dashboard/presentation/widgets/today_meals_section.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/list_group.dart';

// Thursday 24 Sep 2026.
final _today = DateTime(2026, 9, 24, 9, 41);

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1,
  ThemeData? theme,
}) =>
    MaterialApp(
      theme: theme ?? AppTheme.dark,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, mq) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: mq!,
      ),
      home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: child)),
    );

Future<void> _size(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width * 2.625, 923 * 2.625);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

MealEntry _entry(String food, double kcal) => MealEntry(
      foodClientId: food,
      foodName: food,
      quantityInGrams: 100,
      calories: kcal,
      protein: 0,
      carbs: 0,
      fat: 0,
    );

Meal _meal(MealType type, DateTime at, List<MealEntry> entries, {String? name}) =>
    Meal(clientId: '${type.name}$at', dateTime: at, mealType: type, entries: entries, name: name);

TodayMealGroup _group(MealType type, List<Meal> meals) => TodayMealGroup(type: type, meals: meals);

final _canvasGroups = [
  _group(MealType.breakfast, [
    _meal(MealType.breakfast, DateTime(2026, 9, 24, 7, 15), [_entry('Oats', 230), _entry('Berries', 153)],
        name: 'Oats & berries'),
  ]),
  _group(MealType.snack, [
    _meal(MealType.snack, DateTime(2026, 9, 24, 8, 27), [_entry('Apple', 95), _entry('Almonds', 143)]),
  ]),
];

Widget _meals({
  List<TodayMealGroup>? groups,
  VoidCallback? onSeeAll,
  VoidCallback? onMealTap,
  VoidCallback? onAddMeal,
  VoidCallback? onPhoto,
}) =>
    TodayMealsSection(
      groups: groups ?? _canvasGroups,
      onSeeAll: onSeeAll ?? () {},
      onMealTap: onMealTap ?? () {},
      onAddMeal: onAddMeal ?? () {},
      onPhoto: onPhoto ?? () {},
    );

RecentWorkout _strength({
  String id = 's',
  String? template = 'Push day',
  DateTime? at,
  int minutes = 34,
  List<String> exercises = const ['Bench press', 'Dips'],
  int? rpe,
  bool finished = true,
  double? kcal,
}) {
  final start = at ?? DateTime(2026, 9, 23, 17, 30);
  return RecentWorkout(
    clientId: id,
    startedAt: start,
    finishedAt: finished ? start.add(Duration(minutes: minutes)) : null,
    setCount: 6,
    exerciseNames: exercises,
    templateName: template,
    rpe: rpe,
    activeCalories: kcal,
  );
}

RecentWorkout _run() => RecentWorkout(
      clientId: 'run',
      startedAt: DateTime(2026, 9, 22, 7, 45),
      finishedAt: DateTime(2026, 9, 22, 8, 20),
      setCount: 0,
      exerciseNames: const [],
      sessionKind: 'CARDIO',
      activityType: 'RUNNING',
      distanceMeters: 5210,
      movingSeconds: 28 * 60,
      activeCalories: 323,
    );

Widget _workouts(
  List<RecentWorkout> workouts, {
  UnitSystem units = UnitSystem.metric,
  VoidCallback? onSeeAll,
  ValueChanged<String>? onTap,
  ValueChanged<String>? onRate,
}) =>
    RecentWorkoutsSection(
      workouts: workouts,
      unitSystem: units,
      onSeeAll: onSeeAll ?? () {},
      onTap: onTap ?? (_) {},
      onRate: onRate ?? (_) {},
    );

void main() {
  group('today\'s meals', () {
    testWidgets('canvas rows: a named meal, and an unnamed one titled by its type', (tester) async {
      await tester.pumpWidget(_app(_meals()));
      expect(find.text("TODAY'S MEALS"), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);
      // Named: name over "Breakfast · 07:15"
      expect(find.text('Oats & berries'), findsOneWidget);
      expect(find.text('Breakfast · 07:15'), findsOneWidget);
      // Unnamed: the type over its foods and the time
      expect(find.text('Snack'), findsOneWidget);
      expect(find.text('Apple, Almonds · 08:27'), findsOneWidget);
      // kcal totals, whole numbers
      expect(find.textContaining('383', findRichText: true), findsOneWidget);
      expect(find.textContaining('238', findRichText: true), findsOneWidget);
    });

    testWidgets('all meals share one card with dividers, and the quick actions sit inside it',
        (tester) async {
      await tester.pumpWidget(_app(_meals()));
      expect(find.byType(ListGroup), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget, reason: 'between the two rows, none before the actions');
      final card = tester.getRect(find.byType(ListGroup));
      expect(card.contains(tester.getCenter(find.text('Meal'))), isTrue);
      expect(card.contains(tester.getCenter(find.text('Photo'))), isTrue);
    });

    testWidgets('several meals of one type: the type is the title and the earliest time is shown',
        (tester) async {
      await tester.pumpWidget(_app(_meals(groups: [
        _group(MealType.lunch, [
          _meal(MealType.lunch, DateTime(2026, 9, 24, 13, 30), [_entry('Rice', 200)]),
          _meal(MealType.lunch, DateTime(2026, 9, 24, 12, 05), [_entry('Soup', 120)]),
        ]),
      ])));
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Soup, Rice · 12:05'), findsOneWidget);
    });

    testWidgets('at most three foods are listed', (tester) async {
      await tester.pumpWidget(_app(_meals(groups: [
        _group(MealType.dinner, [
          _meal(MealType.dinner, DateTime(2026, 9, 24, 19, 0),
              [_entry('A', 1), _entry('B', 1), _entry('C', 1), _entry('D', 1)]),
        ]),
      ])));
      expect(find.text('A, B, C · 19:00'), findsOneWidget);
    });

    testWidgets('no meals yet: the hint and the quick actions', (tester) async {
      await tester.pumpWidget(_app(_meals(groups: const [])));
      expect(find.text('No meals logged yet.'), findsOneWidget);
      expect(find.text('Meal'), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('callbacks: See all, a row, + Meal, Photo', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(_app(_meals(
        onSeeAll: () => calls.add('all'),
        onMealTap: () => calls.add('row'),
        onAddMeal: () => calls.add('add'),
        onPhoto: () => calls.add('photo'),
      )));
      await tester.tap(find.text('See all'));
      await tester.tap(find.text('Snack'));
      await tester.tap(find.text('Meal'));
      await tester.tap(find.text('Photo'));
      expect(calls, ['all', 'row', 'add', 'photo']);
    });

    testWidgets('the quick actions are 48 dp touch targets', (tester) async {
      await tester.pumpWidget(_app(_meals()));
      for (final label in ['Meal', 'Photo']) {
        final target = find.ancestor(of: find.text(label), matching: find.byType(ConstrainedBox)).evaluate().where(
              (e) => (e.widget as ConstrainedBox).constraints.minHeight == 48,
            );
        expect(target, isNotEmpty, reason: label);
      }
    });

    testWidgets('meal types are tinted differently', (tester) async {
      await tester.pumpWidget(_app(_meals(groups: [
        for (final t in MealType.values)
          _group(t, [_meal(t, DateTime(2026, 9, 24, 9), [_entry('x', 1)])]),
      ])));
      final holders = tester.widgetList<ListIconHolder>(find.byType(ListIconHolder)).toList();
      expect(holders.map((h) => h.color).toSet().length, 4);
      expect(holders.map((h) => h.icon).toSet().length, 4);
    });
  });

  group('recent workouts', () {
    testWidgets('canvas rows: strength and cardio', (tester) async {
      await tester.pumpWidget(_app(_workouts([_strength(), _run()])));
      expect(find.text('RECENT WORKOUTS'), findsOneWidget);
      expect(find.text('Push day'), findsOneWidget);
      expect(find.text('Wed 17:30 · 34 min · 2 exercises'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Tue 07:45 · 5.21 km · 28 min'), findsOneWidget);
      expect(find.textContaining('323', findRichText: true), findsOneWidget);
      expect(tester.widgetList<ListIconHolder>(find.byType(ListIconHolder)).map((h) => h.icon),
          [Icons.fitness_center_rounded, Icons.directions_run]);
    });

    testWidgets('"1 exercise" is singular', (tester) async {
      await tester.pumpWidget(_app(_workouts([_strength(exercises: const ['Squat'])])));
      expect(find.text('Wed 17:30 · 34 min · 1 exercise'), findsOneWidget);
    });

    testWidgets('a strength session without a template is called "Strength"', (tester) async {
      await tester.pumpWidget(_app(_workouts([_strength(template: null)])));
      expect(find.text('Strength'), findsOneWidget);
    });

    testWidgets('cardio uses moving time, not the elapsed time with pauses', (tester) async {
      await tester.pumpWidget(_app(_workouts([_run()])));
      expect(find.textContaining('28 min'), findsOneWidget);
      expect(find.textContaining('35 min'), findsNothing);
    });

    testWidgets('imperial units show miles', (tester) async {
      await tester.pumpWidget(_app(_workouts([_run()], units: UnitSystem.imperial)));
      expect(find.textContaining('mi'), findsWidgets);
      expect(find.textContaining('5.21 km'), findsNothing);
    });

    testWidgets('at most three are shown', (tester) async {
      await tester.pumpWidget(_app(_workouts([
        for (var i = 0; i < 5; i++) _strength(id: 's$i', template: 'W$i'),
      ])));
      expect(find.byType(ListRow), findsNWidgets(3));
    });

    testWidgets('an unrated recent workout gets a "★ Rate" chip that rates, not opens', (tester) async {
      final rated = <String>[];
      final opened = <String>[];
      final recent = DateTime.now().subtract(const Duration(hours: 5));
      await tester.pumpWidget(_app(_workouts(
        [_strength(id: 'today', at: recent)],
        onRate: rated.add,
        onTap: opened.add,
      )));
      expect(find.text('Rate'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      await tester.tap(find.text('Rate'));
      expect(rated, ['today']);
      expect(opened, isEmpty);
    });

    testWidgets('an old unrated workout gets no chip', (tester) async {
      await tester.pumpWidget(_app(_workouts([_strength(at: DateTime.now().subtract(const Duration(days: 9)))])));
      expect(find.text('Rate'), findsNothing);
    });

    testWidgets('a rated one shows its kcal instead, when known', (tester) async {
      await tester.pumpWidget(_app(_workouts([_strength(rpe: 7, kcal: 210)])));
      expect(find.text('Rate'), findsNothing);
      expect(find.textContaining('210', findRichText: true), findsOneWidget);
    });

    testWidgets('an unfinished session says "In progress"', (tester) async {
      await tester.pumpWidget(_app(_workouts([_strength(finished: false)])));
      expect(find.text('In progress'), findsOneWidget);
    });

    testWidgets('tapping a row opens that session; See all opens the list', (tester) async {
      final opened = <String>[];
      var all = 0;
      await tester.pumpWidget(_app(_workouts([_strength(id: 'abc')], onTap: opened.add, onSeeAll: () => all++)));
      await tester.tap(find.text('Push day'));
      await tester.tap(find.text('See all'));
      expect(opened, ['abc']);
      expect(all, 1);
    });

    testWidgets('no workouts: the empty hint', (tester) async {
      await tester.pumpWidget(_app(_workouts(const [])));
      expect(find.text('No workouts logged yet.'), findsOneWidget);
    });
  });

  group('Hungarian', () {
    testWidgets('canvas copy and no English weekday leaks', (tester) async {
      await tester.pumpWidget(_app(
        Column(children: [_meals(), const SizedBox(height: 16), _workouts([_strength(), _run()])]),
        locale: const Locale('hu'),
      ));
      expect(find.text('MAI ÉTKEZÉSEK'), findsOneWidget);
      expect(find.text('Összes'), findsNWidgets(2));
      expect(find.text('Étkezés'), findsOneWidget);
      expect(find.text('Fotó'), findsOneWidget);
      expect(find.text('Reggeli · 07:15'), findsOneWidget);
      expect(find.textContaining('Sze 17:30'), findsOneWidget);
      expect(find.textContaining('5,21 km'), findsOneWidget);
      expect(find.textContaining(RegExp('Wed|Tue')), findsNothing);
    });

    for (final width in [411.0, 360.0]) {
      for (final scale in [1.0, 1.3]) {
        for (final theme in {'dark': AppTheme.dark, 'light': AppTheme.light}.entries) {
          testWidgets('fits without overflow — ${theme.key}, ${width.round()} dp, ×$scale', (tester) async {
            await _size(tester, width);
            await tester.pumpWidget(_app(
              Column(children: [
                _meals(),
                const SizedBox(height: 16),
                _workouts([_strength(at: DateTime.now().subtract(const Duration(hours: 3))), _run()]),
              ]),
              locale: const Locale('hu'),
              textScale: scale,
              theme: theme.value,
            ));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
