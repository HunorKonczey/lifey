import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/trainer/assignments/application/assignments_controller.dart';
import 'package:lifey/features/trainer/assignments/data/assignments_repository.dart';
import 'package:lifey/features/trainer/assignments/domain/assignment.dart';
import 'package:lifey/features/trainer/assignments/presentation/widgets/assign_result_sheet.dart';
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

Assignment _assignment(int id, {int sourceId = 100, String? at}) => Assignment(
      id: id,
      contentType: AssignableContentType.template,
      sourceId: sourceId,
      copiedId: 900 + id,
      assignedAt: DateTime.parse(at ?? '2026-07-08T10:00:00Z'),
    );

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class _FakeAdapter implements HttpClientAdapter {
  final List<String> methods = [];
  final List<String> paths = [];
  final List<Map<String, dynamic>> queries = [];
  final List<Object?> bodies = [];
  Object body = <Object>[];
  int statusCode = 200;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    methods.add(options.method);
    paths.add(options.path);
    queries.add(Map<String, dynamic>.from(options.queryParameters));
    bodies.add(options.data);
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Controller fakes
// ---------------------------------------------------------------------------

class _FakeClientsController extends TrainerClientsController {
  _FakeClientsController(this._clients);

  final List<TrainerClient> _clients;

  @override
  Future<List<TrainerClient>> build() async => _clients;
}

class _FakeAssignmentsRepository extends AssignmentsRepository {
  _FakeAssignmentsRepository(this.byClient) : super(Dio());

  final Map<int, List<Assignment>> byClient;

  final List<int> listedClientIds = [];
  final List<int> unassigned = [];
  BulkAssignmentResult assignResult = const BulkAssignmentResult();
  Object? assignFailure;

  @override
  Future<List<Assignment>> findForClient(int clientId) async {
    listedClientIds.add(clientId);
    return byClient[clientId] ?? const [];
  }

  @override
  Future<BulkAssignmentResult> assign({
    required AssignableContentType contentType,
    required int sourceId,
    required List<int> clientIds,
  }) async {
    if (assignFailure != null) throw assignFailure!;
    return assignResult;
  }

  @override
  Future<void> unassign(int assignmentId) async {
    unassigned.add(assignmentId);
  }
}

ProviderContainer _container({
  required List<TrainerClient> clients,
  required _FakeAssignmentsRepository repo,
}) {
  final container = ProviderContainer(overrides: [
    trainerClientsControllerProvider
        .overrideWith(() => _FakeClientsController(clients)),
    assignmentsRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('repository', () {
    late Dio dio;
    late _FakeAdapter adapter;
    late AssignmentsRepository repo;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://test'));
      adapter = _FakeAdapter();
      dio.httpClientAdapter = adapter;
      repo = AssignmentsRepository(dio);
    });

    test('reads a client\'s assignments', () async {
      adapter.body = [
        {
          'id': 5,
          'contentType': 'RECIPE',
          'sourceId': 12,
          'copiedId': 77,
          'assignedAt': '2026-07-08T10:00:00Z',
        },
      ];

      final assignments = await repo.findForClient(3);

      expect(adapter.paths.single, '/trainer/clients/3/assignments');
      expect(assignments.single.contentType, AssignableContentType.recipe);
      expect(assignments.single.sourceId, 12);
    });

    test('posts the whole batch as one request', () async {
      adapter.statusCode = 201;
      adapter.body = {
        'assignments': [
          {'clientId': 7, 'assignmentId': 91, 'copiedId': 412, 'assignedAt': '2026-07-08T10:00:00Z'},
        ],
        'skippedClientIds': [3],
      };

      final result = await repo.assign(
        contentType: AssignableContentType.template,
        sourceId: 100,
        clientIds: [7, 3],
      );

      expect(adapter.methods.single, 'POST');
      expect(adapter.paths.single, '/trainer/assignments');
      expect(adapter.bodies.single, {
        'clientIds': [7, 3],
        'contentType': 'TEMPLATE',
        'sourceId': 100,
      });
      // A skip is a result, not a failure (docs/35).
      expect(result.assignedClientIds, [7]);
      expect(result.skippedClientIds, [3]);
      expect(result.requestedCount, 2);
    });

    test('an all-skipped batch still parses as a success', () async {
      adapter.body = {'assignments': <Object>[], 'skippedClientIds': [3, 4]};

      final result = await repo.assign(
        contentType: AssignableContentType.recipe,
        sourceId: 1,
        clientIds: [3, 4],
      );

      expect(result.assignedClientIds, isEmpty);
      expect(result.skippedClientIds, [3, 4]);
    });

    test('asks which clients already hold a piece of content', () async {
      adapter.body = [3, 4];

      final ids = await repo.findClientIdsHolding(
        AssignableContentType.recipe,
        12,
      );

      expect(adapter.paths.single, '/trainer/assignments/clients');
      expect(adapter.queries.single['contentType'], 'RECIPE');
      expect(adapter.queries.single['sourceId'], 12);
      expect(ids, [3, 4]);
    });

    test('unassign deletes by assignment id', () async {
      adapter.body = <Object>[];

      await repo.unassign(91);

      expect(adapter.methods.single, 'DELETE');
      expect(adapter.paths.single, '/trainer/assignments/91');
    });
  });

  group('controller', () {
    test('joins every client\'s assignments, newest first', () async {
      final repo = _FakeAssignmentsRepository({
        1: [_assignment(1, at: '2026-07-01T10:00:00Z')],
        2: [_assignment(2, at: '2026-07-09T10:00:00Z')],
      });
      final container = _container(
        clients: [_client(1, 'Anna'), _client(2, 'Bela')],
        repo: repo,
      );

      final rows = await container.read(assignmentsControllerProvider.future);

      expect(repo.listedClientIds, [1, 2]);
      expect(rows.map((r) => r.assignment.id), [2, 1]);
      expect(rows.first.client.displayName, 'Bela Client');
    });

    test('an empty roster asks for nothing at all', () async {
      final repo = _FakeAssignmentsRepository(const {});
      final container = _container(clients: const [], repo: repo);

      final rows = await container.read(assignmentsControllerProvider.future);

      expect(rows, isEmpty);
      expect(repo.listedClientIds, isEmpty);
    });

    test('unassign drops the row without refetching everything', () async {
      final repo = _FakeAssignmentsRepository({
        1: [_assignment(1), _assignment(2)],
      });
      final container = _container(clients: [_client(1, 'Anna')], repo: repo);
      await container.read(assignmentsControllerProvider.future);
      repo.listedClientIds.clear();

      await container.read(assignmentsControllerProvider.notifier).unassign(1);

      expect(repo.unassigned, [1]);
      expect(repo.listedClientIds, isEmpty);
      expect(
        container.read(assignmentsControllerProvider).value!.map((r) => r.assignment.id),
        [2],
      );
    });

    test('a rejected batch throws — nothing was written, so nothing is shown',
        () async {
      final repo = _FakeAssignmentsRepository(const {});
      repo.assignFailure = Exception('403');
      final container = _container(clients: [_client(1, 'Anna')], repo: repo);
      await container.read(assignmentsControllerProvider.future);

      await expectLater(
        container.read(assignmentsControllerProvider.notifier).assign(
              contentType: AssignableContentType.template,
              sourceId: 100,
              clientIds: [1],
            ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('filter', () {
    final anna = AssignmentRow(assignment: _assignment(1), client: _client(1, 'Anna'));
    final bela = AssignmentRow(
      assignment: Assignment(
        id: 2,
        contentType: AssignableContentType.recipe,
        sourceId: 12,
        copiedId: 902,
        assignedAt: DateTime.utc(2026, 7, 9),
      ),
      client: _client(2, 'Bela'),
    );

    test('no filter matches everything', () {
      const filter = AssignmentFilter();
      expect(filter.matches(anna), isTrue);
      expect(filter.matches(bela), isTrue);
    });

    test('by client', () {
      const filter = AssignmentFilter(clientId: 2);
      expect(filter.matches(anna), isFalse);
      expect(filter.matches(bela), isTrue);
    });

    test('by content type', () {
      const filter = AssignmentFilter(contentType: AssignableContentType.recipe);
      expect(filter.matches(anna), isFalse);
      expect(filter.matches(bela), isTrue);
    });

    test('the two combine', () {
      const filter = AssignmentFilter(
        clientId: 1,
        contentType: AssignableContentType.recipe,
      );
      expect(filter.matches(anna), isFalse);
      expect(filter.matches(bela), isFalse);
    });
  });

  group('result sheet', () {
    Future<void> pump(WidgetTester tester, BulkAssignmentResult result) {
      return tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AssignResultSheet(
                result: result,
                clients: [_client(1, 'Anna'), _client(2, 'Bela')],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a clean batch just reports the count', (tester) async {
      await pump(
        tester,
        const BulkAssignmentResult(assignedClientIds: [1, 2]),
      );

      expect(find.text('2 of 2 assigned'), findsOneWidget);
      expect(find.textContaining('skipped'), findsNothing);
    });

    testWidgets('skipped clients are named, with why', (tester) async {
      await pump(
        tester,
        const BulkAssignmentResult(assignedClientIds: [1], skippedClientIds: [2]),
      );

      expect(find.text('1 of 2 assigned'), findsOneWidget);
      expect(find.text('1 client was skipped'), findsOneWidget);
      expect(find.text('Bela Client'), findsOneWidget);
      // The reason matters: without it a skipped row reads as a failure.
      expect(
        find.text('They already had this content, so nothing was changed for them.'),
        findsOneWidget,
      );
    });

    testWidgets('an all-skipped batch is still a result, not an error',
        (tester) async {
      await pump(
        tester,
        const BulkAssignmentResult(skippedClientIds: [1, 2]),
      );

      expect(find.text('0 of 2 assigned'), findsOneWidget);
      expect(find.text('2 clients were skipped'), findsOneWidget);
    });
  });
}
