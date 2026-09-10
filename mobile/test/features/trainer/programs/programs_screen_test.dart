import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/sync/connectivity_status_provider.dart';
import 'package:lifey/features/auth/application/auth_controller.dart';
import 'package:lifey/features/auth/domain/auth_user.dart';
import 'package:lifey/features/chat/application/conversation_list_controller.dart';
import 'package:lifey/features/trainer/clients/application/trainer_clients_controller.dart';
import 'package:lifey/features/trainer/clients/domain/trainer_client.dart';
import 'package:lifey/features/trainer/programs/data/programs_repository.dart';
import 'package:lifey/features/trainer/programs/domain/program.dart';
import 'package:lifey/features/trainer/programs/domain/program_dates.dart';
import 'package:lifey/features/trainer/programs/presentation/program_detail_screen.dart';
import 'package:lifey/features/trainer/programs/presentation/programs_screen.dart';
import 'package:lifey/features/trainer/schedule/domain/schedule.dart';
import 'package:lifey/l10n/app_localizations.dart';

TrainerClient _client(int id, String firstName) => TrainerClient(
      userId: id,
      email: '$id@example.com',
      firstName: firstName,
      lastName: 'Client',
      activeSince: DateTime.utc(2026, 3, 1),
    );

// ---------------------------------------------------------------------------
// Repository wire format
// ---------------------------------------------------------------------------

class _FakeAdapter implements HttpClientAdapter {
  final List<String> methods = [];
  final List<String> paths = [];
  final List<Object?> bodies = [];
  Object body = <Object>[];

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
    bodies.add(options.data);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Screen fakes
// ---------------------------------------------------------------------------

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

class _FakeProgramsRepository extends ProgramsRepository {
  _FakeProgramsRepository({
    this.summaries = const [],
    this.program,
    this.fail = false,
  }) : super(Dio());

  final List<ProgramSummary> summaries;
  final Program? program;
  final bool fail;

  ({int programId, int clientId, DateTime startDate})? lastAssign;

  @override
  Future<List<ProgramSummary>> findAll() async {
    if (fail) throw Exception('offline');
    return summaries;
  }

  @override
  Future<Program> findById(int programId) async {
    if (fail) throw Exception('offline');
    return program!;
  }

  @override
  Future<ProgramAssignmentResult> assign({
    required int programId,
    required int clientId,
    required DateTime startDate,
  }) async {
    lastAssign = (programId: programId, clientId: clientId, startDate: startDate);
    return ProgramAssignmentResult(
      programName: program?.name ?? '',
      startDate: startDate,
      endDate: programEndDate(startDate, program?.weeksCount ?? 1),
      occurrenceCount: 8,
    );
  }

  @override
  Future<List<ProgramAssignmentSummary>> findAssignmentsForClient(int clientId) async =>
      const [];
}

ProgramSlot _slot(int week, ScheduleWeekday day, String name, {String? note}) =>
    ProgramSlot(
      weekNumber: week,
      dayOfWeek: day,
      templateId: 1,
      templateName: name,
      note: note,
    );

Future<void> _pumpList(
  WidgetTester tester, {
  required _FakeProgramsRepository repo,
  bool offline = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        trainerClientsControllerProvider
            .overrideWith(() => _FakeClientsController(const [])),
        programsRepositoryProvider.overrideWithValue(repo),
        isOfflineProvider.overrideWith((ref) => Stream.value(offline)),
        unreadBadgeProvider.overrideWith((ref) => Stream.value(0)),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProgramsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required _FakeProgramsRepository repo,
  List<TrainerClient> clients = const [],
}) async {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        trainerClientsControllerProvider
            .overrideWith(() => _FakeClientsController(clients)),
        programsRepositoryProvider.overrideWithValue(repo),
        isOfflineProvider.overrideWith((ref) => Stream.value(false)),
        unreadBadgeProvider.overrideWith((ref) => Stream.value(0)),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProgramDetailScreen(programId: 1),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('repository', () {
    late Dio dio;
    late _FakeAdapter adapter;
    late ProgramsRepository repo;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://test'));
      adapter = _FakeAdapter();
      dio.httpClientAdapter = adapter;
      repo = ProgramsRepository(dio);
    });

    test('reads the library', () async {
      adapter.body = [
        {
          'id': 1,
          'name': '12-week base',
          'weeksCount': 12,
          'slotsPerWeek': 3,
          'activeAssignmentCount': 2,
        },
      ];

      final programs = await repo.findAll();

      expect(adapter.paths.single, '/trainer/programs');
      expect(programs.single.weeksCount, 12);
      expect(programs.single.activeAssignmentCount, 2);
    });

    test('reads a grid', () async {
      adapter.body = {
        'id': 1,
        'name': 'Base',
        'weeksCount': 2,
        'workouts': [
          {
            'id': 9,
            'weekNumber': 1,
            'dayOfWeek': 'MONDAY',
            'templateId': 100,
            'templateName': 'Push day',
            'timeOfDay': '18:00:00',
            'note': 'Add 2.5 kg',
          },
        ],
      };

      final program = await repo.findById(1);

      expect(adapter.paths.single, '/trainer/programs/1');
      final slot = program.workouts.single;
      expect(slot.dayOfWeek, ScheduleWeekday.monday);
      expect(slot.timeOfDay, const ScheduleTime(18, 0));
      expect(slot.note, 'Add 2.5 kg');
    });

    test('assigns one client from a Monday', () async {
      adapter.body = {
        'assignmentId': 5,
        'programName': 'Base',
        'startDate': '2026-07-13',
        'endDate': '2026-08-09',
        'occurrenceCount': 8,
      };

      final result = await repo.assign(
        programId: 1,
        clientId: 7,
        startDate: DateTime(2026, 7, 13),
      );

      expect(adapter.methods.single, 'POST');
      expect(adapter.paths.single, '/trainer/programs/1/assignments');
      expect(adapter.bodies.single, {'clientId': 7, 'startDate': '2026-07-13'});
      expect(result.occurrenceCount, 8);
      expect(weeksBetween(result.startDate, result.endDate), 4);
    });

    test('stopping a run goes by assignment id', () async {
      adapter.body = <Object>[];

      await repo.cancelAssignment(5);

      expect(adapter.methods.single, 'DELETE');
      expect(adapter.paths.single, '/trainer/program-assignments/5');
    });
  });

  group('the library', () {
    testWidgets('names each program, its length and how many are running',
        (tester) async {
      await _pumpList(
        tester,
        repo: _FakeProgramsRepository(summaries: const [
          ProgramSummary(
            id: 1,
            name: '12-week base',
            weeksCount: 12,
            slotsPerWeek: 3,
            activeAssignmentCount: 2,
          ),
        ]),
      );

      expect(find.text('12-week base'), findsOneWidget);
      expect(find.textContaining('12 weeks'), findsOneWidget);
      expect(find.text('2 running'), findsOneWidget);
    });

    testWidgets('says where programs come from when there are none',
        (tester) async {
      await _pumpList(tester, repo: _FakeProgramsRepository());

      expect(find.text('No programs yet'), findsOneWidget);
      expect(find.text('Open on the web'), findsOneWidget);
    });

    testWidgets('offline with nothing loaded says so', (tester) async {
      await _pumpList(
        tester,
        repo: _FakeProgramsRepository(fail: true),
        offline: true,
      );

      expect(find.text('No connection'), findsOneWidget);
    });
  });

  group('the detail', () {
    final program = Program(
      id: 1,
      name: 'Base',
      weeksCount: 3,
      workouts: [
        _slot(1, ScheduleWeekday.thursday, 'Pull day'),
        _slot(1, ScheduleWeekday.monday, 'Push day', note: 'Add 2.5 kg'),
        _slot(3, ScheduleWeekday.monday, 'Push day'),
      ],
    );

    testWidgets('opens the first week, in weekday order, with its note',
        (tester) async {
      await _pumpDetail(tester, repo: _FakeProgramsRepository(program: program));

      expect(find.text('Week 1'), findsOneWidget);
      expect(find.text('Push day'), findsWidgets);
      expect(find.text('Add 2.5 kg'), findsOneWidget);
      // Week 1 is expanded; the others are collapsed but listed.
      expect(find.text('Week 2'), findsOneWidget);
      expect(find.text('Week 3'), findsOneWidget);
    });

    testWidgets('a week with nothing in it reads as a rest week',
        (tester) async {
      await _pumpDetail(tester, repo: _FakeProgramsRepository(program: program));

      // Week 2 has no slots — said out loud, not left blank.
      expect(find.text('Rest week'), findsOneWidget);
    });

    testWidgets('points at the web for editing, without hiding it',
        (tester) async {
      await _pumpDetail(tester, repo: _FakeProgramsRepository(program: program));

      await tester.scrollUntilVisible(
        find.text('Programs are built on the web'),
        300,
      );
      expect(find.text('Programs are built on the web'), findsOneWidget);
    });
  });

  group('starting a client', () {
    final program = Program(
      id: 1,
      name: 'Base',
      weeksCount: 4,
      workouts: [_slot(1, ScheduleWeekday.monday, 'Push day')],
    );

    testWidgets('defaults to the next Monday and says what the run covers',
        (tester) async {
      await _pumpDetail(
        tester,
        repo: _FakeProgramsRepository(program: program),
        clients: [_client(7, 'Anna')],
      );

      await tester.tap(find.text('Start program'));
      await tester.pumpAndSettle();

      expect(find.text('Start someone on Base'), findsOneWidget);
      // The run's span is spelled out before anything is sent, and it says
      // four weeks because that is the program's length.
      final summary = tester
          .widgetList<Text>(find.textContaining('Runs '))
          .map((t) => t.data)
          .single;
      expect(summary, contains('4 weeks'));
    });

    testWidgets('needs a client picked before it will submit', (tester) async {
      await _pumpDetail(
        tester,
        repo: _FakeProgramsRepository(program: program),
        clients: [_client(7, 'Anna')],
      );

      await tester.tap(find.text('Start program'));
      await tester.pumpAndSettle();

      final before = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Start program'),
      );
      expect(before.onPressed, isNull);

      await tester.tap(find.text('Anna Client'));
      await tester.pumpAndSettle();

      final after = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Start program'),
      );
      expect(after.onPressed, isNotNull);
    });

    testWidgets('submits a Monday, and reports what landed in the calendar',
        (tester) async {
      final repo = _FakeProgramsRepository(program: program);
      await _pumpDetail(tester, repo: repo, clients: [_client(7, 'Anna')]);

      await tester.tap(find.text('Start program'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anna Client'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Start program'));
      await tester.pumpAndSettle();

      expect(repo.lastAssign!.clientId, 7);
      expect(repo.lastAssign!.startDate.weekday, DateTime.monday);
      expect(find.text('8 sessions added to their calendar'), findsOneWidget);
    });
  });
}
