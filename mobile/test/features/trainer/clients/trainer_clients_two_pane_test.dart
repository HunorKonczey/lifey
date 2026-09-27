import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifey/core/sync/connectivity_status_provider.dart';
import 'package:lifey/features/chat/application/conversation_list_controller.dart';
import 'package:lifey/features/trainer/clients/presentation/widgets/client_card.dart';
import 'package:lifey/features/trainer/clients/presentation/widgets/client_list_row.dart';
import 'package:lifey/features/trainer/clients/application/selected_client_controller.dart';
import 'package:lifey/features/trainer/clients/application/trainer_clients_controller.dart';
import 'package:lifey/features/trainer/clients/domain/trainer_client.dart';
import 'package:lifey/features/trainer/clients/presentation/trainer_clients_screen.dart';
import 'package:lifey/features/trainer/shared/trainer_layout.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/trainer_view_menu.dart';

/// docs/chat/41-trainer-mobile-v2-plan.md §8.2 — the same list, two layouts:
/// a phone pushes the client detail, a tablet shows it beside the list.

final _clients = [
  TrainerClient(
      userId: 7,
      firstName: 'Anna',
      lastName: 'Kovács',
      email: 'anna@example.com',
      activeSince: DateTime(2026, 1, 5)),
  TrainerClient(
      userId: 9,
      firstName: 'Béla',
      lastName: 'Nagy',
      email: 'bela@example.com',
      activeSince: DateTime(2026, 2, 1)),
];

class _FakeClients extends TrainerClientsController {
  _FakeClients(this._clients);

  final List<TrainerClient> _clients;

  @override
  Future<List<TrainerClient>> build() async => _clients;

  @override
  Future<void> refresh() async {}
}

/// Records what the phone layout pushes, without building the detail screen's
/// own dependencies.
final _pushed = <String>[];

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  List<TrainerClient>? clients,
}) async {
  _pushed.clear();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // Mirrors the real route tree (trainerShellLocation + ':clientId'), with a
  // stand-in for the detail so the phone case doesn't pull in its providers.
  final router = GoRouter(routes: [
    GoRoute(
      path: trainerShellLocation,
      builder: (_, __) => const TrainerClientsScreen(),
      routes: [
        GoRoute(
          path: ':clientId',
          builder: (_, state) {
            _pushed.add(state.pathParameters['clientId']!);
            return const Scaffold(body: Text('pushed detail'));
          },
        ),
      ],
    ),
  ], initialLocation: trainerShellLocation);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      trainerClientsControllerProvider
          .overrideWith(() => _FakeClients(clients ?? _clients)),
      isOfflineProvider.overrideWith((ref) => Stream.value(false)),
      unreadBadgeProvider.overrideWith((ref) => Stream.value(0)),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
}

const _phone = Size(390, 844);
const _tablet = Size(1194, 834);

void main() {
  /// The embedded detail loads real client data, which never settles under
  /// test — pump a few frames instead of waiting for quiet.
  Future<void> tapCard(WidgetTester tester, String name) async {
    await tester.tap(find.ancestor(
      of: find.text(name),
      matching: find.byWidgetPredicate((w) => w is ClientCard || w is ClientListRow),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  ProviderContainer containerOf(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(TrainerClientsScreen)));

  testWidgets('on a phone, tapping a client still pushes the detail', (tester) async {
    await _pump(tester, size: _phone);

    await tapCard(tester, 'Anna Kovács');

    expect(_pushed, ['7']);
  });

  testWidgets('on a tablet, the list stays and nothing is pushed', (tester) async {
    await _pump(tester, size: _tablet);

    expect(find.byType(TrainerTwoPane), findsOneWidget);
    expect(find.textContaining('Pick a client'), findsOneWidget);

    await tapCard(tester, 'Anna Kovács');

    expect(_pushed, isEmpty, reason: 'nothing is pushed on a tablet');
    expect(containerOf(tester).read(selectedClientControllerProvider), 7);
    // The list is still there beside the detail.
    expect(find.text('Béla Nagy'), findsOneWidget);
  });

  testWidgets('a second tap moves the pane to the other client', (tester) async {
    await _pump(tester, size: _tablet);

    await tapCard(tester, 'Anna Kovács');
    await tapCard(tester, 'Béla Nagy');

    expect(containerOf(tester).read(selectedClientControllerProvider), 9);
  });

  testWidgets('a client who left the list is dropped from the pane', (tester) async {
    await _pump(tester, size: _tablet);
    await tapCard(tester, 'Béla Nagy');

    final container = containerOf(tester);
    container.read(trainerClientsControllerProvider.notifier).state =
        AsyncValue.data([_clients.first]);
    await tester.pump();

    expect(container.read(selectedClientControllerProvider), isNull);
    expect(find.textContaining('Pick a client'), findsOneWidget);
  });

  testWidgets('a phone never renders the two-pane layout', (tester) async {
    await _pump(tester, size: _phone);

    expect(find.byType(TrainerTwoPane), findsNothing);
    expect(find.textContaining('Pick a client'), findsNothing);
  });
}
