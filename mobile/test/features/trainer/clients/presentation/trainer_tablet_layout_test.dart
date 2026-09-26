import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/sync/connectivity_status_provider.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/auth/application/auth_controller.dart';
import 'package:lifey/features/auth/domain/auth_user.dart';
import 'package:lifey/features/chat/application/conversation_list_controller.dart';
import 'package:lifey/features/trainer/client_detail/data/client_detail_repository.dart';
import 'package:lifey/features/trainer/client_detail/domain/client_data.dart';
import 'package:lifey/features/trainer/client_detail/domain/client_workout_session.dart';
import 'package:lifey/features/trainer/client_detail/presentation/widgets/client_action_bar.dart';
import 'package:lifey/features/trainer/client_detail/presentation/widgets/client_detail_header.dart';
import 'package:lifey/features/trainer/client_detail/presentation/widgets/upcoming_card.dart';
import 'package:lifey/features/trainer/clients/application/client_search_controller.dart';
import 'package:lifey/features/trainer/clients/application/trainer_clients_controller.dart';
import 'package:lifey/features/trainer/clients/domain/trainer_client.dart';
import 'package:lifey/features/trainer/clients/presentation/trainer_clients_screen.dart';
import 'package:lifey/features/trainer/clients/presentation/widgets/client_card.dart';
import 'package:lifey/features/trainer/clients/presentation/widgets/client_list_row.dart';
import 'package:lifey/features/trainer/schedule/data/schedule_repository.dart';
import 'package:lifey/features/trainer/schedule/domain/schedule.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/metric_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(id: 7, email: 'coach@example.com', roles: ['ROLE_USER', 'ROLE_TRAINER']);
}

class _FakeClientsController extends TrainerClientsController {
  _FakeClientsController(this._clients);

  final List<TrainerClient> _clients;

  @override
  Future<List<TrainerClient>> build() async => _clients;
}

class _FakeDetailRepository extends ClientDetailRepository {
  _FakeDetailRepository() : super(Dio());

  @override
  Future<ClientStatistics> fetchStatistics(int c, ClientStatisticsPeriod p) async =>
      const ClientStatistics(totalCalories: 11417, workoutCount: 6);

  @override
  Future<List<ClientStepDay>> fetchSteps(int c, {DateTime? from, DateTime? to}) async =>
      [ClientStepDay(date: DateTime.now(), steps: 8353)];

  @override
  Future<List<ClientWeightEntry>> fetchWeights(int c, {DateTime? from, DateTime? to}) async => [
        ClientWeightEntry(date: DateTime.now().subtract(const Duration(days: 20)), weight: 66.0),
        ClientWeightEntry(date: DateTime.now(), weight: 64.6),
      ];

  @override
  Future<ClientNutritionGoals> fetchNutritionGoals(int c) async => const ClientNutritionGoals(dailyCalorieGoal: 2400);

  @override
  Future<ClientSessionPage> fetchWorkoutSessions(int c, {int page = 0, int size = 20}) async =>
      const ClientSessionPage(sessions: [], isLast: true);
}

class _FakeScheduleRepository extends ScheduleRepository {
  _FakeScheduleRepository(this.occurrences) : super(Dio());

  final List<CalendarSession> occurrences;

  @override
  Future<List<CalendarSession>> findOccurrencesForClient(int clientId, {required DateTime from, required DateTime to}) async =>
      occurrences;

  @override
  Future<List<ScheduleSummary>> findSchedulesForClient(int clientId) async => const [];
}

TrainerClient _client(int id, String first, String last, {int daysSinceActivity = 0, int daysSinceWeight = 0}) {
  final now = DateTime.now();
  return TrainerClient(
    userId: id,
    email: '$first.$last@example.com'.toLowerCase(),
    firstName: first,
    lastName: last,
    activeSince: now.subtract(const Duration(days: 200)),
    lastActivityAt: now.subtract(Duration(days: daysSinceActivity)),
    lastWeightAt: now.subtract(Duration(days: daysSinceWeight)),
  );
}

final _clients = [
  _client(1, 'Anna', 'Kovacs'),
  _client(2, 'Bence', 'Nagy', daysSinceActivity: 4),
  _client(3, 'Eszter', 'Szabó'),
  _client(4, 'Gábor', 'Tóth', daysSinceWeight: 9),
];

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1184, 800),
  Locale locale = const Locale('en'),
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        trainerClientsControllerProvider.overrideWith(() => _FakeClientsController(_clients)),
        clientDetailRepositoryProvider.overrideWithValue(_FakeDetailRepository()),
        scheduleRepositoryProvider.overrideWithValue(
          _FakeScheduleRepository([
            CalendarSession(
              sessionId: 1,
              scheduledFor: DateTime.now().add(const Duration(days: 1)),
              scheduledTime: const ScheduleTime(17, 30),
              templateName: 'Pull day',
              status: OccurrenceStatus.upcoming,
            ),
          ]),
        ),
        isOfflineProvider.overrideWith((ref) => Stream.value(false)),
        unreadBadgeProvider.overrideWith((ref) => Stream.value(0)),
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
        home: const TrainerClientsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the list pane (canvas Lifey 6 › Trainer tablet)', () {
    testWidgets('is 400 dp wide, with a search field and one compact row per client', (tester) async {
      await _pump(tester);

      expect(tester.getSize(find.byType(TextField)).width, lessThan(400));
      expect(find.byType(ClientListRow), findsNWidgets(4));
      // The phone's card, with its KPI tiles and chips, does not belong in a
      // pane the detail sits beside.
      expect(find.byType(ClientCard), findsNothing);
      expect(find.text('Search clients'), findsOneWidget);
      expect(tester.getTopRight(find.byType(ClientListRow).first).dx, lessThanOrEqualTo(400));
    });

    testWidgets('a row says how the client is doing: active, gone quiet, weigh-in due', (tester) async {
      await _pump(tester);

      expect(find.text('Active today'), findsWidgets);
      expect(find.text('Last seen 4 days ago'), findsOneWidget);
      expect(find.text('Weigh-in due'), findsOneWidget);
    });

    testWidgets('search narrows the list by name, ignoring case and Hungarian accents', (tester) async {
      await _pump(tester);

      await tester.enterText(find.byType(TextField), 'szabo');
      await tester.pumpAndSettle();
      expect(find.byType(ClientListRow), findsOneWidget);
      expect(find.text('Eszter Szabó'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.byType(ClientListRow), findsNothing);
      expect(find.text('No results'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(ClientListRow), findsNWidgets(4));
    });

    testWidgets('picking a client fills the pane beside it without navigating', (tester) async {
      await _pump(tester);
      expect(find.text('Pick a client'), findsOneWidget);

      await tester.tap(find.text('Anna Kovacs'));
      await tester.pumpAndSettle();

      // The name now appears twice: the row, and the detail header.
      expect(find.text('Anna Kovacs'), findsNWidgets(2));
      expect(find.byType(ClientDetailWideHeader), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      final row = tester.widget<ClientListRow>(find.widgetWithText(ClientListRow, 'Anna Kovacs'));
      expect(row.selected, isTrue);

      await tester.tap(find.text('Bence Nagy'));
      await tester.pumpAndSettle();
      expect(find.text('Bence Nagy'), findsNWidgets(2));
      expect(find.text('Anna Kovacs'), findsOneWidget);
    });
  });

  group('the wide detail pane', () {
    testWidgets('has Message and Schedule in the header, four KPIs in a row, and the trend beside Upcoming',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Anna Kovacs'));
      await tester.pumpAndSettle();

      // Actions are in the header, not under the tabs.
      expect(find.byType(ClientActionBar), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Message'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Schedule'), findsOneWidget);

      final tiles = find.byType(MetricTile);
      expect(tiles, findsNWidgets(4));
      final ys = [for (var i = 0; i < 4; i++) tester.getTopLeft(tiles.at(i)).dy];
      expect(ys.toSet().length, 1, reason: 'one row');

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Pull day'), findsOneWidget);
      final trend = tester.getTopLeft(find.text('Weight trend'));
      final upcoming = tester.getTopLeft(find.text('Upcoming'));
      expect(upcoming.dy, closeTo(trend.dy, 2), reason: 'side by side');
      expect(upcoming.dx, greaterThan(trend.dx));
    });

    testWidgets('a 900 dp window leaves a narrow pane, which keeps the phone layout', (tester) async {
      await _pump(tester, size: const Size(900, 700));
      await tester.tap(find.text('Anna Kovacs'));
      await tester.pumpAndSettle();

      expect(find.byType(ClientDetailWideHeader), findsNothing);
      expect(find.byType(ClientActionBar), findsOneWidget);
      expect(find.byType(UpcomingCard), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final (name, locale) in [('English', const Locale('en')), ('Hungarian', const Locale('hu'))]) {
      for (final (mode, theme) in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
        testWidgets('fits 1184 x 800 at x 1.3 in $name, $mode', (tester) async {
          await _pump(tester, locale: locale, textScale: 1.3, theme: theme);
          await tester.tap(find.text('Anna Kovacs'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  test('the search folds case and Hungarian accents, and a blank query keeps everyone', () {
    expect(filterClients(_clients, '').length, 4);
    expect(filterClients(_clients, '  ').length, 4);
    expect(filterClients(_clients, 'GABOR').single.firstName, 'Gábor');
    expect(filterClients(_clients, 'toth').single.lastName, 'Tóth');
    expect(filterClients(_clients, 'example.com').length, 4); // the email counts too
  });
}
