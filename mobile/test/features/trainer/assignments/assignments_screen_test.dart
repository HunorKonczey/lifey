import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/sync/connectivity_status_provider.dart';
import 'package:lifey/core/theme/app_theme.dart';
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

class _FakeAssignmentsRepository extends AssignmentsRepository {
  _FakeAssignmentsRepository(this.byClient) : super(Dio());

  final Map<int, List<Assignment>> byClient;
  final List<({AssignableContentType type, int sourceId, List<int> clientIds})> assigned = [];

  @override
  Future<List<Assignment>> findForClient(int clientId) async => byClient[clientId] ?? const [];

  @override
  Future<List<int>> findClientIdsHolding(AssignableContentType contentType, int sourceId) async => [
        for (final entry in byClient.entries)
          if (entry.value.any((a) => a.contentType == contentType && a.sourceId == sourceId)) entry.key,
      ];

  @override
  Future<BulkAssignmentResult> assign({
    required AssignableContentType contentType,
    required int sourceId,
    required List<int> clientIds,
  }) async {
    assigned.add((type: contentType, sourceId: sourceId, clientIds: clientIds));
    return BulkAssignmentResult(assignedClientIds: clientIds);
  }
}

TrainerClient _client(int id, String firstName) => TrainerClient(
      userId: id,
      email: '$id@example.com',
      firstName: firstName,
      lastName: 'Client',
      activeSince: DateTime.utc(2026, 3, 1),
    );

Assignment _assignment(int id, AssignableContentType type, int sourceId) => Assignment(
      id: id,
      contentType: type,
      sourceId: sourceId,
      copiedId: 900 + id,
      assignedAt: DateTime.utc(2026, 7, 8, 10),
    );

const _content = [
  AssignableContent(type: AssignableContentType.template, sourceId: 100, name: 'Push day'),
  AssignableContent(type: AssignableContentType.recipe, sourceId: 200, name: 'Overnight oats'),
];

Future<_FakeAssignmentsRepository> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double textScale = 1,
  ThemeData? theme,
  Size size = const Size(390, 900),
  bool empty = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = _FakeAssignmentsRepository(
    empty
        ? const {}
        : {
            1: [_assignment(1, AssignableContentType.template, 100)],
            2: [_assignment(2, AssignableContentType.recipe, 200)],
          },
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        trainerClientsControllerProvider.overrideWith(() => _FakeClientsController([_client(1, 'Anna'), _client(2, 'Bela')])),
        assignmentsRepositoryProvider.overrideWithValue(repo),
        assignableContentProvider.overrideWithValue(_content),
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
        home: const AssignmentsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('the list (canvas Lifey 6 family)', () {
    testWidgets('has the clay TRAINER mark, the title, and one card per assignment', (tester) async {
      await _pump(tester);

      expect(find.text('TRAINER'), findsOneWidget);
      expect(find.text('Push day'), findsOneWidget);
      expect(find.text('Overnight oats'), findsOneWidget);
      expect(find.textContaining('Anna Client · 8 Jul 2026'), findsOneWidget);
      expect(find.byTooltip('Remove assignment'), findsNWidgets(2));
    });

    testWidgets('the type pills narrow the list', (tester) async {
      // Wide enough that the third pill is built (the row is a lazy list).
      await _pump(tester, size: const Size(800, 900));

      await tester.tap(find.text('Recipe'));
      await tester.pumpAndSettle();

      expect(find.text('Overnight oats'), findsOneWidget);
      expect(find.text('Push day'), findsNothing);
    });

    testWidgets('nothing assigned yet says so', (tester) async {
      await _pump(tester, empty: true);

      expect(find.text('Nothing assigned yet'), findsOneWidget);
    });
  });

  group('assigning', () {
    testWidgets('two steps in a sheet: pick the content, tick the clients who do not have it yet', (tester) async {
      final repo = await _pump(tester);

      await tester.tap(find.text('Assign'));
      await tester.pumpAndSettle();
      expect(find.text('What are you assigning?'), findsOneWidget);

      await tester.tap(find.text('Push day').last);
      await tester.pumpAndSettle();

      // Anna already holds it: shown, locked and ticked; Bela is free to pick.
      expect(find.text('Anna Client'), findsWidgets);
      final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(checkboxes.length, 2);
      expect(checkboxes[0].onChanged, isNull);
      expect(checkboxes[0].value, isTrue);
      expect(checkboxes[1].onChanged, isNotNull);

      await tester.tap(find.text('Bela Client'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
      await tester.pumpAndSettle();

      expect(repo.assigned.single.clientIds, [2]);
      expect(find.text('1 of 1 assigned'), findsOneWidget);
    });
  });

  for (final (name, locale) in [('English', const Locale('en')), ('Hungarian', const Locale('hu'))]) {
    for (final (mode, theme) in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
      testWidgets('the list and the sheet fit 360 dp at x 1.3 in $name, $mode', (tester) async {
        await _pump(tester, locale: locale, textScale: 1.3, theme: theme, size: const Size(360, 900));
        expect(tester.takeException(), isNull);

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
