import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/sync/connectivity_status_provider.dart';
import 'package:lifey/features/auth/application/auth_controller.dart';
import 'package:lifey/features/auth/domain/auth_user.dart';
import 'package:lifey/features/chat/application/conversation_list_controller.dart';
import 'package:lifey/features/trainer/assignments/application/assignable_content.dart';
import 'package:lifey/features/trainer/assignments/data/assignments_repository.dart';
import 'package:lifey/features/trainer/assignments/domain/assignment.dart';
import 'package:lifey/features/trainer/assignments/presentation/assignments_screen.dart';
import 'package:lifey/features/trainer/clients/application/trainer_clients_controller.dart';
import 'package:lifey/features/trainer/clients/domain/trainer_client.dart';
import 'package:lifey/l10n/app_localizations.dart';

TrainerClient _client(int id, String firstName) => TrainerClient(
      userId: id,
      email: '$id@example.com',
      firstName: firstName,
      lastName: 'Client',
      activeSince: DateTime.utc(2026, 3, 1),
    );

Assignment _assignment(
  int id, {
  AssignableContentType type = AssignableContentType.template,
  int sourceId = 100,
}) =>
    Assignment(
      id: id,
      contentType: type,
      sourceId: sourceId,
      copiedId: 900 + id,
      assignedAt: DateTime.utc(2026, 7, 8),
    );

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

class _FakeAssignmentsRepository extends AssignmentsRepository {
  _FakeAssignmentsRepository(
    this.byClient, {
    this.holders = const [],
    this.fail = false,
  }) : super(Dio());

  final Map<int, List<Assignment>> byClient;
  final List<int> holders;
  final bool fail;

  final List<int> unassigned = [];
  BulkAssignmentResult assignResult = const BulkAssignmentResult();
  List<int>? lastAssignedTo;

  @override
  Future<List<Assignment>> findForClient(int clientId) async {
    if (fail) throw Exception('offline');
    return byClient[clientId] ?? const [];
  }

  @override
  Future<List<int>> findClientIdsHolding(
    AssignableContentType contentType,
    int sourceId,
  ) async =>
      holders;

  @override
  Future<BulkAssignmentResult> assign({
    required AssignableContentType contentType,
    required int sourceId,
    required List<int> clientIds,
  }) async {
    lastAssignedTo = clientIds;
    return assignResult;
  }

  @override
  Future<void> unassign(int assignmentId) async => unassigned.add(assignmentId);
}

const _content = [
  AssignableContent(
    type: AssignableContentType.template,
    sourceId: 100,
    name: 'Push day',
  ),
  AssignableContent(
    type: AssignableContentType.recipe,
    sourceId: 12,
    name: 'Oat bowl',
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required _FakeAssignmentsRepository repo,
  List<TrainerClient> clients = const [],
  List<AssignableContent> content = _content,
  bool offline = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        trainerClientsControllerProvider
            .overrideWith(() => _FakeClientsController(clients)),
        assignmentsRepositoryProvider.overrideWithValue(repo),
        assignableContentProvider.overrideWithValue(content),
        isOfflineProvider.overrideWith((ref) => Stream.value(offline)),
        unreadBadgeProvider.overrideWith((ref) => Stream.value(0)),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AssignmentsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the list', () {
    testWidgets('names the content and who has it', (tester) async {
      await _pump(
        tester,
        clients: [_client(1, 'Anna')],
        repo: _FakeAssignmentsRepository({
          1: [_assignment(1)],
        }),
      );

      expect(find.text('Push day'), findsOneWidget);
      expect(find.textContaining('Anna Client'), findsWidgets);
    });

    testWidgets('a source the trainer deleted still shows, so it can be revoked',
        (tester) async {
      await _pump(
        tester,
        clients: [_client(1, 'Anna')],
        repo: _FakeAssignmentsRepository({
          1: [_assignment(1, sourceId: 999)],
        }),
      );

      expect(find.text('Deleted content'), findsOneWidget);
    });

    testWidgets('says nothing is assigned when nothing is', (tester) async {
      await _pump(
        tester,
        clients: [_client(1, 'Anna')],
        repo: _FakeAssignmentsRepository(const {}),
      );

      expect(find.text('Nothing assigned yet'), findsOneWidget);
    });

    testWidgets('a filter with no matches is not the same as nothing assigned',
        (tester) async {
      await _pump(
        tester,
        clients: [_client(1, 'Anna')],
        repo: _FakeAssignmentsRepository({
          1: [_assignment(1)],
        }),
      );

      await tester.tap(find.text('Recipe').last);
      await tester.pumpAndSettle();

      expect(find.text('Nothing matches these filters.'), findsOneWidget);
      expect(find.text('Nothing assigned yet'), findsNothing);
    });

    testWidgets('offline with nothing loaded says so', (tester) async {
      await _pump(
        tester,
        clients: [_client(1, 'Anna')],
        repo: _FakeAssignmentsRepository(const {}, fail: true),
        offline: true,
      );

      expect(find.text('No connection'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('a load that succeeded is shown even while offline',
        (tester) async {
      // Offline is not a blanket override: a list that made it to the screen
      // stays readable, and the app-wide banner says the rest.
      await _pump(
        tester,
        clients: [_client(1, 'Anna')],
        repo: _FakeAssignmentsRepository({
          1: [_assignment(1)],
        }),
        offline: true,
      );

      expect(find.text('Push day'), findsOneWidget);
      expect(find.text('No connection'), findsNothing);
    });
  });

  group('revoking', () {
    testWidgets('asks first, naming what happens to the client\'s copy',
        (tester) async {
      final repo = _FakeAssignmentsRepository({
        1: [_assignment(1)],
      });
      await _pump(tester, clients: [_client(1, 'Anna')], repo: repo);

      await tester.tap(find.byTooltip('Remove assignment'));
      await tester.pumpAndSettle();

      expect(find.text('Remove this assignment?'), findsOneWidget);
      expect(
        find.text("Push day will be removed from Anna Client's account too."),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(repo.unassigned, [1]);
      expect(find.text('Assignment removed.'), findsOneWidget);
    });

    testWidgets('cancelling leaves the assignment alone', (tester) async {
      final repo = _FakeAssignmentsRepository({
        1: [_assignment(1)],
      });
      await _pump(tester, clients: [_client(1, 'Anna')], repo: repo);

      await tester.tap(find.byTooltip('Remove assignment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.unassigned, isEmpty);
    });
  });

  group('assigning', () {
    testWidgets('content first, then clients, with a running count',
        (tester) async {
      final repo = _FakeAssignmentsRepository(const {});
      repo.assignResult = const BulkAssignmentResult(assignedClientIds: [1, 2]);
      await _pump(
        tester,
        clients: [_client(1, 'Anna'), _client(2, 'Bela')],
        repo: repo,
      );

      await tester.tap(find.text('Assign'));
      await tester.pumpAndSettle();
      expect(find.text('What are you assigning?'), findsOneWidget);

      await tester.tap(find.text('Push day'));
      await tester.pumpAndSettle();
      expect(find.text('Who gets Push day?'), findsOneWidget);
      expect(find.text('No one selected'), findsOneWidget);

      await tester.tap(find.text('Anna Client'));
      await tester.pumpAndSettle();
      expect(find.text('1 client selected'), findsOneWidget);

      await tester.tap(find.text('Bela Client'));
      await tester.pumpAndSettle();
      expect(find.text('2 clients selected'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
      await tester.pumpAndSettle();

      expect(repo.lastAssignedTo, [1, 2]);
      expect(find.text('2 of 2 assigned'), findsOneWidget);
    });

    testWidgets('a client who already has the content is locked, not hidden',
        (tester) async {
      final repo = _FakeAssignmentsRepository(const {}, holders: [2]);
      await _pump(
        tester,
        clients: [_client(1, 'Anna'), _client(2, 'Bela')],
        repo: repo,
      );

      await tester.tap(find.text('Assign'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Push day'));
      await tester.pumpAndSettle();

      expect(find.text('Bela Client'), findsOneWidget);
      expect(find.text('Already has it'), findsOneWidget);

      // Tapping the locked row changes nothing.
      await tester.tap(find.text('Bela Client'));
      await tester.pumpAndSettle();
      expect(find.text('No one selected'), findsOneWidget);
    });

    testWidgets('the sheet explains why there is nothing to assign',
        (tester) async {
      await _pump(
        tester,
        clients: [_client(1, 'Anna')],
        repo: _FakeAssignmentsRepository(const {}),
        content: const [],
      );

      await tester.tap(find.text('Assign'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('You have no templates or recipes to assign yet'),
        findsOneWidget,
      );
    });
  });
}
