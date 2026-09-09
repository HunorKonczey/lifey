import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/sync/connectivity_status_provider.dart';
import 'package:lifey/features/auth/application/auth_controller.dart';
import 'package:lifey/features/auth/domain/auth_user.dart';
import 'package:lifey/features/chat/application/conversation_list_controller.dart';
import 'package:lifey/features/trainer/clients/application/trainer_clients_controller.dart';
import 'package:lifey/features/trainer/clients/domain/trainer_client.dart';
import 'package:lifey/features/trainer/clients/presentation/trainer_clients_screen.dart';
import 'package:lifey/features/trainer/clients/presentation/widgets/client_card.dart';
import 'package:lifey/l10n/app_localizations.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<AuthUser?> build() async => const AuthUser(
        id: 7,
        email: 'coach@example.com',
        firstName: 'Coach',
        lastName: 'One',
        roles: ['ROLE_USER', 'ROLE_TRAINER'],
      );
}

class _FakeClientsController extends TrainerClientsController {
  _FakeClientsController({this.clients, this.error});

  final List<TrainerClient>? clients;
  final Object? error;

  @override
  Future<List<TrainerClient>> build() async {
    if (error != null) throw error!;
    return clients ?? const [];
  }
}

TrainerClient _client({
  required int id,
  required String firstName,
  int daysSinceActivity = 0,
  int daysSinceWeight = 0,
  int missedWorkouts = 0,
}) {
  final now = DateTime.now();
  return TrainerClient(
    userId: id,
    email: '$id@example.com',
    firstName: firstName,
    lastName: 'Client',
    activeSince: now.subtract(const Duration(days: 200)),
    lastActivityAt: now.subtract(Duration(days: daysSinceActivity)),
    lastWeightAt: now.subtract(Duration(days: daysSinceWeight)),
    missedWorkoutCount: missedWorkouts,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  List<TrainerClient>? clients,
  Object? error,
  bool offline = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        trainerClientsControllerProvider.overrideWith(
          () => _FakeClientsController(clients: clients, error: error),
        ),
        isOfflineProvider.overrideWith((ref) => Stream.value(offline)),
        unreadBadgeProvider.overrideWith((ref) => Stream.value(0)),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TrainerClientsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _cardNamesInOrder(WidgetTester tester) => tester
    .widgetList<ClientCard>(find.byType(ClientCard))
    .map((card) => card.client.displayName)
    .toList();

void main() {
  testWidgets('lists every client, with the trainer-view chip in the app bar',
      (tester) async {
    await _pump(tester, clients: [
      _client(id: 1, firstName: 'Anna'),
      _client(id: 2, firstName: 'Bela'),
    ]);

    expect(find.text('Anna Client'), findsOneWidget);
    expect(find.text('Bela Client'), findsOneWidget);
    expect(find.text('TRAINER'), findsOneWidget);
    expect(find.byType(ClientCard), findsNWidgets(2));
  });

  testWidgets('splits out a "needs attention" section when someone is flagged',
      (tester) async {
    await _pump(tester, clients: [
      _client(id: 1, firstName: 'Anna'),
      _client(id: 2, firstName: 'Bela', missedWorkouts: 2),
    ]);

    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('All clients'), findsOneWidget);
    // The flagged client is pulled to the top regardless of the sort.
    expect(_cardNamesInOrder(tester), ['Bela Client', 'Anna Client']);
  });

  testWidgets('hides the "needs attention" block entirely when nobody is flagged',
      (tester) async {
    await _pump(tester, clients: [_client(id: 1, firstName: 'Anna')]);

    expect(find.text('Needs attention'), findsNothing);
    expect(find.text('All clients'), findsNothing);
  });

  testWidgets('shows the empty state, pointing at the web invite flow',
      (tester) async {
    await _pump(tester, clients: const []);

    expect(find.text('No clients yet'), findsOneWidget);
    expect(find.byType(ClientCard), findsNothing);
  });

  testWidgets('offline with nothing loaded shows the full-screen offline state',
      (tester) async {
    await _pump(tester, error: Exception('no route to host'), offline: true);

    expect(find.text('No connection'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    // Not the generic error view — offline is its own state here.
    expect(find.text('Something went wrong'), findsNothing);
  });

  testWidgets('a failure while online shows the error state with a retry',
      (tester) async {
    await _pump(tester, error: Exception('boom'));

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('the sort chips reorder the list', (tester) async {
    await _pump(tester, clients: [
      _client(id: 1, firstName: 'Anna', missedWorkouts: 1),
      _client(id: 2, firstName: 'Bela', missedWorkouts: 4),
      _client(id: 3, firstName: 'Cili', missedWorkouts: 2),
    ]);

    // All three are flagged, so they share one section and the sort is the
    // only thing deciding the order.
    expect(_cardNamesInOrder(tester), ['Anna Client', 'Bela Client', 'Cili Client']);

    await tester.tap(find.text('Most missed'));
    await tester.pumpAndSettle();

    expect(_cardNamesInOrder(tester), ['Bela Client', 'Cili Client', 'Anna Client']);
  });
}
