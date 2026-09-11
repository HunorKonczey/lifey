import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/sync/connectivity_status_provider.dart';
import 'package:lifey/features/auth/application/auth_controller.dart';
import 'package:lifey/features/auth/domain/auth_user.dart';
import 'package:lifey/features/nutrition/domain/meal.dart' show MealType;
import 'package:lifey/features/trainer/client_detail/application/client_detail_tab_preference.dart';
import 'package:lifey/features/trainer/client_detail/data/client_detail_repository.dart';
import 'package:lifey/features/trainer/client_detail/domain/client_data.dart';
import 'package:lifey/features/trainer/client_detail/domain/client_detail_tab.dart';
import 'package:lifey/features/trainer/client_detail/presentation/client_detail_screen.dart';
import 'package:lifey/features/trainer/clients/application/trainer_clients_controller.dart';
import 'package:lifey/features/trainer/clients/domain/trainer_client.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<AuthUser?> build() async => const AuthUser(
        id: 7,
        email: 'coach@example.com',
        roles: ['ROLE_USER', 'ROLE_TRAINER'],
      );
}

class _FakeClientsController extends TrainerClientsController {
  _FakeClientsController(this._clients);

  final List<TrainerClient> _clients;

  @override
  Future<List<TrainerClient>> build() async => _clients;
}

/// Stands in for every read the detail tabs make. Extends the real
/// repository so the providers under test are the real ones — only the
/// network is replaced.
class _FakeDetailRepository extends ClientDetailRepository {
  _FakeDetailRepository({
    this.statistics = const ClientStatistics(),
    this.steps = const [],
    this.weights = const [],
    this.meals = const [],
    this.goals = const ClientNutritionGoals(),
    this.failWith,
  }) : super(Dio());

  final ClientStatistics statistics;
  final List<ClientStepDay> steps;
  final List<ClientWeightEntry> weights;
  final List<ClientMeal> meals;
  final ClientNutritionGoals goals;
  final Object? failWith;

  void _maybeFail() {
    if (failWith != null) throw failWith!;
  }

  @override
  Future<ClientStatistics> fetchStatistics(int c, ClientStatisticsPeriod p) async {
    _maybeFail();
    return statistics;
  }

  @override
  Future<List<ClientStepDay>> fetchSteps(int c, {DateTime? from, DateTime? to}) async {
    _maybeFail();
    return steps;
  }

  @override
  Future<List<ClientWeightEntry>> fetchWeights(int c,
      {DateTime? from, DateTime? to}) async {
    _maybeFail();
    return weights;
  }

  @override
  Future<List<ClientMeal>> fetchMealsForDay(int c, DateTime day) async {
    _maybeFail();
    return meals;
  }

  @override
  Future<ClientNutritionGoals> fetchNutritionGoals(int c) async {
    _maybeFail();
    return goals;
  }
}

final _client = TrainerClient(
  userId: 42,
  email: 'anna@example.com',
  firstName: 'Anna',
  lastName: 'Client',
  activeSince: DateTime.utc(2026, 3, 1),
);

ClientStepDay _step(int daysAgo, int steps) => ClientStepDay(
      date: DateTime.now().subtract(Duration(days: daysAgo)),
      steps: steps,
    );

ClientWeightEntry _weight(int daysAgo, double kg) => ClientWeightEntry(
      date: DateTime.now().subtract(Duration(days: daysAgo)),
      weight: kg,
    );

ClientMeal _meal(MealType type, String food, double kcal) => ClientMeal(
      id: 1,
      dateTime: DateTime.now(),
      mealType: type,
      name: '',
      entries: [
        ClientMealEntry(
          foodName: food,
          quantityInGrams: 100,
          calories: kcal,
          protein: 10,
          carbs: 20,
          fat: 5,
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  _FakeDetailRepository? repository,
  List<TrainerClient>? clients,
  bool offline = false,
  int clientId = 42,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        trainerClientsControllerProvider
            .overrideWith(() => _FakeClientsController(clients ?? [_client])),
        clientDetailRepositoryProvider
            .overrideWithValue(repository ?? _FakeDetailRepository()),
        isOfflineProvider.overrideWith((ref) => Stream.value(offline)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ClientDetailScreen(clientId: clientId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The nutrition tab is taller than a test viewport, so its lower half has
/// to be scrolled to before it exists in the tree at all.
Future<void> _scrollNutritionTo(WidgetTester tester, Finder target) {
  return tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('trainerNutritionList')),
      matching: find.byType(Scrollable),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('header and tabs', () {
    testWidgets('names the client and opens on the overview', (tester) async {
      await _pump(
        tester,
        repository: _FakeDetailRepository(
          statistics: const ClientStatistics(totalCalories: 14000, workoutCount: 3),
          steps: [_step(1, 8000), _step(0, 10000)],
          weights: [_weight(7, 72.0), _weight(0, 71.4)],
        ),
      );

      expect(find.text('Anna Client'), findsOneWidget);
      expect(find.text('anna@example.com'), findsOneWidget);
      // 14000 kcal over the 7-day window.
      expect(find.text('2,000 kcal'), findsOneWidget);
      expect(find.text('71.4 kg'), findsOneWidget);
      expect(find.text('-0.6 kg'), findsOneWidget);
      expect(find.text('9,000'), findsOneWidget);
    });

    testWidgets('a client who is no longer ours gets an explanation, not an error',
        (tester) async {
      await _pump(tester, clients: const [], clientId: 42);

      expect(find.text('Not your client'), findsOneWidget);
    });
  });

  group('statistics tab', () {
    testWidgets('shows the period chips, the totals and the read-only badge',
        (tester) async {
      await _pump(
        tester,
        repository: _FakeDetailRepository(
          statistics: const ClientStatistics(
            totalCalories: 14350,
            workoutCount: 4,
            latestWeight: 71.2,
          ),
          weights: [_weight(10, 72.0), _weight(0, 71.2)],
        ),
      );

      await tester.tap(find.text('Statistics'));
      await tester.pumpAndSettle();

      expect(find.text('Read-only'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);
      expect(find.text('14,350 kcal'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Weight trend'), findsOneWidget);
    });

    testWidgets('a single reading is called out instead of drawn as a trend',
        (tester) async {
      await _pump(
        tester,
        repository: _FakeDetailRepository(weights: [_weight(0, 71.2)]),
      );

      await tester.tap(find.text('Statistics'));
      await tester.pumpAndSettle();

      expect(
        find.text('One reading so far — not enough for a trend.'),
        findsOneWidget,
      );
    });
  });

  group('steps tab', () {
    testWidgets('charts the window and lists the days newest first',
        (tester) async {
      await _pump(
        tester,
        repository: _FakeDetailRepository(steps: [_step(1, 8214), _step(0, 10500)]),
      );

      await tester.tap(find.text('Steps'));
      await tester.pumpAndSettle();

      expect(find.text('Last 30 days'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('8,214'), findsOneWidget);
      expect(find.text('10,500'), findsOneWidget);
    });

    testWidgets('says nothing was synced when the window is empty', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Steps'));
      await tester.pumpAndSettle();

      expect(find.text('No steps recorded'), findsOneWidget);
    });
  });

  group('nutrition tab', () {
    testWidgets('groups the day by meal type and shows goals', (tester) async {
      await _pump(
        tester,
        repository: _FakeDetailRepository(
          meals: [_meal(MealType.breakfast, 'Oats', 390)],
          goals: const ClientNutritionGoals(dailyCalorieGoal: 2200),
        ),
      );

      await tester.tap(find.text('Nutrition'));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Oats'), findsOneWidget);
      expect(find.text('390 kcal / 2,200 kcal'), findsOneWidget);

      // The untouched meal groups still show, each saying so — the last one
      // is below the fold on a test-sized screen.
      await _scrollNutritionTo(tester, find.text('Day total: 390 kcal'));
      expect(find.text('Nothing logged'), findsNWidgets(3));
    });

    testWidgets('says so when the client has no goals set', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Nutrition'));
      await tester.pumpAndSettle();

      expect(find.text('No daily goals set for this client yet.'), findsOneWidget);

      await _scrollNutritionTo(tester, find.text('Nothing logged on this day.'));
      expect(find.text('Nothing logged on this day.'), findsOneWidget);
    });
  });

  group('failure states', () {
    testWidgets('a failed read offers a retry', (tester) async {
      await _pump(
        tester,
        repository: _FakeDetailRepository(failWith: Exception('boom')),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('offline with nothing loaded says so instead', (tester) async {
      await _pump(
        tester,
        repository: _FakeDetailRepository(failWith: Exception('no route to host')),
        offline: true,
      );

      expect(find.text('No connection'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });
  });

  group('tab memory', () {
    testWidgets('opens on the tab this client was last viewed on',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'trainer.clientDetail.lastTab.42': ClientDetailTab.steps.storageKey,
      });

      await _pump(tester);

      // The steps tab's own empty state, not the overview's cards.
      expect(find.text('No steps recorded'), findsOneWidget);
    });

    testWidgets('switching tabs writes the choice back', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Nutrition'));
      await tester.pumpAndSettle();

      final stored = await ClientDetailTabPreference().lastTabFor(42);
      expect(stored, ClientDetailTab.nutrition);
    });

    testWidgets('one client\'s tab does not follow the trainer to another',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'trainer.clientDetail.lastTab.42': ClientDetailTab.steps.storageKey,
      });

      final other = TrainerClient(
        userId: 43,
        email: 'bela@example.com',
        firstName: 'Bela',
        lastName: 'Client',
        activeSince: DateTime.utc(2026, 3, 1),
      );
      await _pump(tester, clients: [_client, other], clientId: 43);

      // Bela has no remembered tab, so he opens on the overview.
      expect(find.text('Avg. daily calories'), findsOneWidget);
    });
  });
}
