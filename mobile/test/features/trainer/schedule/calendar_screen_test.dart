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
import 'package:lifey/features/trainer/schedule/application/calendar_controller.dart';
import 'package:lifey/features/trainer/schedule/data/schedule_repository.dart';
import 'package:lifey/features/trainer/schedule/domain/schedule.dart';
import 'package:lifey/features/trainer/schedule/presentation/calendar_screen.dart';
import 'package:lifey/features/trainer/schedule/presentation/widgets/month_overview.dart';
import 'package:lifey/l10n/app_localizations.dart';

TrainerClient _client(int id, String firstName) => TrainerClient(
      userId: id,
      email: '$id@example.com',
      firstName: firstName,
      lastName: 'Client',
      activeSince: DateTime.utc(2026, 3, 1),
    );

/// Anchored on today so the screen, which opens on the current week, actually
/// shows it. Real calendars are relative; so is this fixture.
CalendarSession _session({
  int sessionId = 1,
  int clientId = 1,
  int daysFromToday = 0,
  ScheduleTime? at,
  OccurrenceStatus status = OccurrenceStatus.upcoming,
  String? templateName = 'Push day',
}) {
  final today = dateOnly(DateTime.now());
  return CalendarSession(
    sessionId: sessionId,
    clientId: clientId,
    scheduledFor: today.add(Duration(days: daysFromToday)),
    scheduledTime: at,
    templateName: templateName,
    status: status,
  );
}

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

class _FakeScheduleRepository extends ScheduleRepository {
  _FakeScheduleRepository({
    this.sessions = const [],
    this.fail = false,
    this.schedules = const [],
  }) : super(Dio());

  final List<CalendarSession> sessions;
  final bool fail;
  final List<ScheduleSummary> schedules;

  final List<int> cancelledOccurrences = [];

  @override
  Future<List<ScheduleSummary>> findSchedulesForClient(int clientId) async =>
      schedules;

  @override
  Future<List<CalendarSession>> findOccurrences({
    required DateTime from,
    required DateTime to,
  }) async {
    if (fail) throw Exception('offline');
    return sessions
        .where((s) =>
            !s.scheduledFor.isBefore(from) && !s.scheduledFor.isAfter(to))
        .toList();
  }

  @override
  Future<void> cancelOccurrence(int sessionId) async =>
      cancelledOccurrences.add(sessionId);
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeScheduleRepository repo,
  List<TrainerClient> clients = const [],
  bool offline = false,
  Size size = const Size(400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_FakeAuthController.new),
        trainerClientsControllerProvider
            .overrideWith(() => _FakeClientsController(clients)),
        scheduleRepositoryProvider.overrideWithValue(repo),
        isOfflineProvider.overrideWith((ref) => Stream.value(offline)),
        unreadBadgeProvider.overrideWith((ref) => Stream.value(0)),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TrainerCalendarScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the agenda', () {
    testWidgets('lists this week\'s sessions with client and template',
        (tester) async {
      await _pump(
        tester,
        clients: [_client(1, 'Anna')],
        repo: _FakeScheduleRepository(sessions: [
          _session(at: const ScheduleTime(18, 0)),
        ]),
      );

      expect(find.text('Anna Client'), findsWidgets);
      expect(find.text('Push day'), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
    });

    testWidgets('untimed sessions sit under their own divider', (tester) async {
      await _pump(
        tester,
        clients: [_client(1, 'Anna')],
        repo: _FakeScheduleRepository(sessions: [
          _session(sessionId: 1, at: const ScheduleTime(9, 0)),
          _session(sessionId: 2, templateName: 'Mobility'),
        ]),
      );

      expect(find.text('During the day'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('an empty week says so rather than showing seven blanks',
        (tester) async {
      await _pump(tester, repo: _FakeScheduleRepository());

      expect(find.text('Nothing scheduled'), findsOneWidget);
    });

    testWidgets('offline is its own state, not a network error', (tester) async {
      await _pump(
        tester,
        repo: _FakeScheduleRepository(fail: true),
        offline: true,
      );

      expect(find.text('No connection'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('a failure while online offers a retry', (tester) async {
      await _pump(tester, repo: _FakeScheduleRepository(fail: true));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('the client filter', () {
    testWidgets('narrows the agenda and says so in the header', (tester) async {
      await _pump(
        tester,
        clients: [_client(1, 'Anna'), _client(2, 'Bela')],
        repo: _FakeScheduleRepository(sessions: [
          _session(sessionId: 1, clientId: 1, templateName: 'Push day'),
          _session(sessionId: 2, clientId: 2, templateName: 'Pull day'),
        ]),
      );

      expect(find.text('Push day'), findsOneWidget);
      expect(find.text('Pull day'), findsOneWidget);

      await tester.tap(find.byTooltip('Filter by client'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anna Client').last);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Push day'), findsOneWidget);
      expect(find.text('Pull day'), findsNothing);
      // An active filter has to be visible from the header, or the calendar
      // silently lies about how busy the week is.
      expect(find.text('1 client'), findsOneWidget);
    });

    testWidgets('no selection means everyone, not nobody', (tester) async {
      await _pump(
        tester,
        clients: [_client(1, 'Anna'), _client(2, 'Bela')],
        repo: _FakeScheduleRepository(sessions: [
          _session(sessionId: 1, clientId: 1, templateName: 'Push day'),
          _session(sessionId: 2, clientId: 2, templateName: 'Pull day'),
        ]),
      );

      expect(find.text('Push day'), findsOneWidget);
      expect(find.text('Pull day'), findsOneWidget);
      expect(find.textContaining('client'), findsNothing);
    });
  });

  group('the peek sheet', () {
    testWidgets('offers to cancel an upcoming session', (tester) async {
      final repo = _FakeScheduleRepository(sessions: [_session()]);
      await _pump(tester, clients: [_client(1, 'Anna')], repo: repo);

      await tester.tap(find.text('Push day'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel this session'), findsOneWidget);

      await tester.tap(find.text('Cancel this session'));
      await tester.pumpAndSettle();
      // The confirmation names the boundary between this and cancelling the
      // whole series.
      expect(
        find.text('Only this one session is cancelled. The rest of the schedule stays.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(repo.cancelledOccurrences, [1]);
    });

    testWidgets('does not offer to cancel one that already happened',
        (tester) async {
      await _pump(
        tester,
        clients: [_client(1, 'Anna')],
        repo: _FakeScheduleRepository(sessions: [
          _session(status: OccurrenceStatus.done),
        ]),
      );

      await tester.tap(find.text('Push day'));
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsWidgets);
      // The backend answers 409 for anything past — offering it would be
      // offering a button that cannot work.
      expect(find.text('Cancel this session'), findsNothing);
    });
  });

  group('the recurrence line', () {
    testWidgets('the peek looks the rule up, since the calendar has only an id',
        (tester) async {
      await _pump(
        tester,
        clients: [_client(1, 'Anna')],
        repo: _FakeScheduleRepository(
          sessions: [
            CalendarSession(
              sessionId: 1,
              clientId: 1,
              scheduledFor: dateOnly(DateTime.now()),
              scheduledTime: const ScheduleTime(18, 0),
              templateName: 'Push day',
              status: OccurrenceStatus.upcoming,
              scheduleId: 3,
            ),
          ],
          schedules: [
            ScheduleSummary(
              id: 3,
              clientId: 1,
              templateId: 100,
              templateName: 'Push day',
              recurrence: ScheduleRecurrence.weekly,
              daysOfWeek: const [ScheduleWeekday.monday, ScheduleWeekday.thursday],
              timeOfDay: const ScheduleTime(18, 0),
              startDate: DateTime(2026, 8, 3),
              endDate: DateTime(2026, 10, 6),
            ),
          ],
        ),
      );

      await tester.tap(find.text('Push day'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Every Mon, Thu'), findsOneWidget);
    });

    testWidgets('a rule that cannot be found leaves the line out entirely',
        (tester) async {
      await _pump(
        tester,
        clients: [_client(1, 'Anna')],
        repo: _FakeScheduleRepository(
          sessions: [
            CalendarSession(
              sessionId: 1,
              clientId: 1,
              scheduledFor: dateOnly(DateTime.now()),
              templateName: 'Push day',
              status: OccurrenceStatus.upcoming,
              scheduleId: 999,
            ),
          ],
        ),
      );

      await tester.tap(find.text('Push day'));
      await tester.pumpAndSettle();

      // Better a missing line than a guessed one.
      expect(find.textContaining('Every'), findsNothing);
    });
  });

  group('the month view', () {
    testWidgets('is reachable and hands back to the agenda on a day tap',
        (tester) async {
      await _pump(
        tester,
        clients: [_client(1, 'Anna')],
        repo: _FakeScheduleRepository(sessions: [_session()]),
      );

      await tester.tap(find.byTooltip('Month view'));
      await tester.pumpAndSettle();
      expect(find.byType(MonthOverview), findsOneWidget);

      await tester.tap(find.text('${DateTime.now().day}').last);
      await tester.pumpAndSettle();

      expect(find.byType(MonthOverview), findsNothing);
      expect(find.text('Push day'), findsOneWidget);
    });

    testWidgets('a narrow screen gets dots, a wide one gets names',
        (tester) async {
      // The threshold is a width, not an orientation: a landscape phone and a
      // portrait tablet are the same problem.
      await _pump(
        tester,
        clients: [_client(1, 'Anna')],
        repo: _FakeScheduleRepository(sessions: [_session()]),
        size: const Size(monthGridMinWidth + 40, 900),
      );

      await tester.tap(find.byTooltip('Month view'));
      await tester.pumpAndSettle();

      expect(find.text('Push day'), findsOneWidget);
    });

    testWidgets('the narrow month view names nothing', (tester) async {
      await _pump(
        tester,
        clients: [_client(1, 'Anna')],
        repo: _FakeScheduleRepository(sessions: [_session()]),
        size: const Size(monthGridMinWidth - 40, 900),
      );

      await tester.tap(find.byTooltip('Month view'));
      await tester.pumpAndSettle();

      expect(find.byType(MonthOverview), findsOneWidget);
      expect(find.text('Push day'), findsNothing);
    });
  });
}
