import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/trainer/client_detail/presentation/tabs/schedule_tab.dart';
import 'package:lifey/features/trainer/programs/data/programs_repository.dart';
import 'package:lifey/features/trainer/programs/domain/program.dart';
import 'package:lifey/features/trainer/schedule/application/calendar_controller.dart';
import 'package:lifey/features/trainer/schedule/data/schedule_repository.dart';
import 'package:lifey/features/trainer/schedule/domain/schedule.dart';
import 'package:lifey/features/workouts/application/workout_template_controller.dart';
import 'package:lifey/features/workouts/domain/workout_template.dart';
import 'package:lifey/l10n/app_localizations.dart';

ScheduleSummary _schedule({
  int id = 3,
  ScheduleRecurrence recurrence = ScheduleRecurrence.weekly,
  List<ScheduleWeekday> days = const [ScheduleWeekday.monday],
  int remaining = 13,
  DateTime? cancelledAt,
}) {
  return ScheduleSummary(
    id: id,
    clientId: 7,
    templateId: 100,
    templateName: 'Push day',
    recurrence: recurrence,
    daysOfWeek: days,
    timeOfDay: const ScheduleTime(18, 0),
    startDate: DateTime(2026, 8, 3),
    endDate: DateTime(2026, 10, 6),
    doneCount: 4,
    missedCount: 1,
    remainingCount: remaining,
    cancelledAt: cancelledAt,
  );
}

CalendarSession _occurrence({int sessionId = 55, int daysFromToday = 1}) {
  return CalendarSession(
    sessionId: sessionId,
    scheduledFor: dateOnly(DateTime.now()).add(Duration(days: daysFromToday)),
    scheduledTime: const ScheduleTime(18, 0),
    templateName: 'Push day',
    status: OccurrenceStatus.upcoming,
    scheduleId: 3,
  );
}

class _FakeTemplateController extends WorkoutTemplateController {
  _FakeTemplateController(this._templates);

  final List<WorkoutTemplate> _templates;

  @override
  Stream<List<WorkoutTemplate>> build() => Stream.value(_templates);
}

/// The tab also reads the client's program runs (T6), so a test of it needs
/// this even when the story under test is about schedules.
class _FakeProgramsRepository extends ProgramsRepository {
  _FakeProgramsRepository({this.runs = const []}) : super(Dio());

  final List<ProgramAssignmentSummary> runs;

  final List<int> cancelledRuns = [];

  @override
  Future<List<ProgramAssignmentSummary>> findAssignmentsForClient(int clientId) async =>
      runs;

  @override
  Future<void> cancelAssignment(int assignmentId) async =>
      cancelledRuns.add(assignmentId);
}

ProgramAssignmentSummary _run({
  int id = 11,
  int remaining = 9,
  DateTime? cancelledAt,
}) {
  final monday = DateTime(2026, 8, 3);
  return ProgramAssignmentSummary(
    id: id,
    clientId: 7,
    programId: 1,
    programName: '12-week base',
    startDate: monday,
    endDate: DateTime(2026, 8, 30),
    doneCount: 3,
    missedCount: 0,
    remainingCount: remaining,
    cancelledAt: cancelledAt,
  );
}

class _FakeScheduleRepository extends ScheduleRepository {
  _FakeScheduleRepository({
    this.schedules = const [],
    this.occurrences = const [],
  }) : super(Dio());

  final List<ScheduleSummary> schedules;
  final List<CalendarSession> occurrences;

  final List<int> cancelledSchedules = [];
  Map<String, Object?>? lastCreate;

  @override
  Future<List<ScheduleSummary>> findSchedulesForClient(int clientId) async =>
      schedules;

  @override
  Future<List<CalendarSession>> findOccurrencesForClient(
    int clientId, {
    required DateTime from,
    required DateTime to,
  }) async =>
      occurrences;

  @override
  Future<void> createSchedule({
    required int clientId,
    required int templateId,
    required ScheduleRecurrence recurrence,
    required List<ScheduleWeekday> daysOfWeek,
    required DateTime startDate,
    required DateTime endDate,
    ScheduleTime? timeOfDay,
  }) async {
    lastCreate = {
      'clientId': clientId,
      'templateId': templateId,
      'recurrence': recurrence,
      'daysOfWeek': daysOfWeek,
      'startDate': startDate,
      'endDate': endDate,
      'timeOfDay': timeOfDay,
    };
  }

  @override
  Future<void> cancelSchedule(int scheduleId) async =>
      cancelledSchedules.add(scheduleId);
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeScheduleRepository repo,
  _FakeProgramsRepository? programs,
  List<WorkoutTemplate> templates = const [],
}) async {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(repo),
        programsRepositoryProvider
            .overrideWithValue(programs ?? _FakeProgramsRepository()),
        workoutTemplateControllerProvider
            .overrideWith(() => _FakeTemplateController(templates)),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ClientScheduleTab(clientId: 7, offline: false)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the tab', () {
    testWidgets('shows the rule in words, with how it is going',
        (tester) async {
      await _pump(
        tester,
        repo: _FakeScheduleRepository(
          schedules: [_schedule()],
          occurrences: [_occurrence()],
        ),
      );

      expect(find.text('Schedules'), findsOneWidget);
      expect(find.text('Coming up'), findsOneWidget);
      expect(find.textContaining('Every Mon'), findsOneWidget);
      expect(find.textContaining('18:00'), findsWidgets);
      expect(find.text('4 done · 1 missed · 13 to go'), findsOneWidget);
    });

    testWidgets('says so when there is nothing scheduled', (tester) async {
      await _pump(tester, repo: _FakeScheduleRepository());

      expect(find.text('Nothing scheduled yet'), findsOneWidget);
    });

    testWidgets('a cancelled series is shown but cannot be cancelled again',
        (tester) async {
      await _pump(
        tester,
        repo: _FakeScheduleRepository(
          schedules: [_schedule(cancelledAt: DateTime(2026, 8, 1))],
        ),
      );

      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.byTooltip('Cancel schedule'), findsNothing);
    });
  });

  group('program runs', () {
    testWidgets('lead the tab, with where the client is in them',
        (tester) async {
      await _pump(
        tester,
        repo: _FakeScheduleRepository(schedules: [_schedule()]),
        programs: _FakeProgramsRepository(runs: [_run()]),
      );

      expect(find.text('Programs'), findsOneWidget);
      expect(find.text('12-week base'), findsOneWidget);
      expect(find.textContaining('of 4'), findsOneWidget);
      // The bigger commitment reads first; the loose schedules follow.
      final programsY = tester.getTopLeft(find.text('Programs')).dy;
      final schedulesY = tester.getTopLeft(find.text('Schedules')).dy;
      expect(programsY, lessThan(schedulesY));
    });

    testWidgets('stopping one names the same boundary as a schedule',
        (tester) async {
      final programs = _FakeProgramsRepository(runs: [_run(remaining: 9)]);
      await _pump(
        tester,
        repo: _FakeScheduleRepository(),
        programs: programs,
      );

      await tester.tap(find.byTooltip('Stop program'));
      await tester.pumpAndSettle();

      expect(
        find.text('The 9 sessions still to come are cancelled. '
            'What already happened stays.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(programs.cancelledRuns, [11]);
      expect(find.text('Program stopped.'), findsOneWidget);
    });

    testWidgets('a stopped run is shown but cannot be stopped again',
        (tester) async {
      await _pump(
        tester,
        repo: _FakeScheduleRepository(),
        programs: _FakeProgramsRepository(
          runs: [_run(cancelledAt: DateTime(2026, 8, 10))],
        ),
      );

      expect(find.text('12-week base'), findsOneWidget);
      expect(find.byTooltip('Stop program'), findsNothing);
    });
  });

  group('cancelling a series', () {
    testWidgets('names how many future sessions go, and that the past stays',
        (tester) async {
      final repo = _FakeScheduleRepository(schedules: [_schedule(remaining: 13)]);
      await _pump(tester, repo: repo);

      await tester.tap(find.byTooltip('Cancel schedule'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel this schedule?'), findsOneWidget);
      expect(
        find.text('The 13 sessions still to come are cancelled. '
            'What already happened stays.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(repo.cancelledSchedules, [3]);
      expect(find.text('Schedule cancelled.'), findsOneWidget);
    });

    testWidgets('backing out leaves the series alone', (tester) async {
      final repo = _FakeScheduleRepository(schedules: [_schedule()]);
      await _pump(tester, repo: repo);

      await tester.tap(find.byTooltip('Cancel schedule'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.cancelledSchedules, isEmpty);
    });
  });

  group('creating a schedule', () {
    const template = WorkoutTemplate(
      clientId: 'local-1',
      id: 100,
      name: 'Push day',
      exercises: [],
    );

    testWidgets('says up front how many sessions it will create',
        (tester) async {
      await _pump(
        tester,
        repo: _FakeScheduleRepository(),
        templates: const [template],
      );

      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();

      // A one-off, the default, is one session on the start date.
      expect(find.textContaining('This creates one session'), findsOneWidget);
    });

    testWidgets('a weekly rule with no day picked cannot be submitted',
        (tester) async {
      await _pump(
        tester,
        repo: _FakeScheduleRepository(),
        templates: const [template],
      );

      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();

      expect(find.text('Pick at least one day of the week.'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create schedule'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('picking days turns the summary into a count', (tester) async {
      await _pump(
        tester,
        repo: _FakeScheduleRepository(),
        templates: const [template],
      );

      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Mon'));
      await tester.pumpAndSettle();

      expect(find.textContaining('This creates'), findsOneWidget);
      expect(find.text('Pick at least one day of the week.'), findsNothing);
    });

    testWidgets('submits the chosen rule', (tester) async {
      final repo = _FakeScheduleRepository();
      await _pump(tester, repo: repo, templates: const [template]);

      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<WorkoutTemplate>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Push day').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create schedule'));
      await tester.pumpAndSettle();

      expect(repo.lastCreate, isNotNull);
      expect(repo.lastCreate!['clientId'], 7);
      expect(repo.lastCreate!['templateId'], 100);
      expect(repo.lastCreate!['recurrence'], ScheduleRecurrence.once);
    });

    testWidgets('explains itself when there is no template to schedule',
        (tester) async {
      await _pump(tester, repo: _FakeScheduleRepository());

      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('You have no workout templates yet'),
        findsOneWidget,
      );
    });
  });
}
