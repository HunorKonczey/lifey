import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/trainer/schedule/application/calendar_controller.dart';
import 'package:lifey/features/trainer/schedule/data/schedule_repository.dart';
import 'package:lifey/features/trainer/schedule/domain/schedule.dart';

class _FakeAdapter implements HttpClientAdapter {
  final List<String> methods = [];
  final List<String> paths = [];
  final List<Map<String, dynamic>> queries = [];
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
    queries.add(Map<String, dynamic>.from(options.queryParameters));
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

void main() {
  late Dio dio;
  late _FakeAdapter adapter;
  late ScheduleRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test'));
    adapter = _FakeAdapter();
    dio.httpClientAdapter = adapter;
    repo = ScheduleRepository(dio);
  });

  group('creating', () {
    test('sends the whole rule, days as the API spells them', () async {
      adapter.body = <String, dynamic>{};

      await repo.createSchedule(
        clientId: 7,
        templateId: 100,
        recurrence: ScheduleRecurrence.weekly,
        daysOfWeek: [ScheduleWeekday.monday, ScheduleWeekday.thursday],
        startDate: DateTime(2026, 8, 3),
        endDate: DateTime(2026, 10, 6),
        timeOfDay: const ScheduleTime(18, 0),
      );

      expect(adapter.methods.single, 'POST');
      expect(adapter.paths.single, '/trainer/schedules');
      expect(adapter.bodies.single, {
        'clientId': 7,
        'templateId': 100,
        'recurrence': 'WEEKLY',
        'daysOfWeek': ['MONDAY', 'THURSDAY'],
        'timeOfDay': '18:00',
        'startDate': '2026-08-03',
        'endDate': '2026-10-06',
      });
    });

    test('a one-off still carries an end date, because the column is not null',
        () async {
      adapter.body = <String, dynamic>{};

      await repo.createSchedule(
        clientId: 7,
        templateId: 100,
        recurrence: ScheduleRecurrence.once,
        daysOfWeek: const [],
        startDate: DateTime(2026, 8, 3),
        endDate: DateTime(2026, 8, 3),
      );

      final body = adapter.bodies.single as Map<String, dynamic>;
      expect(body['endDate'], '2026-08-03');
      expect(body['daysOfWeek'], isEmpty);
      // No time was chosen, so none is sent — null would be a value.
      expect(body.containsKey('timeOfDay'), isFalse);
    });

    test('a single-digit time is zero-padded to HH:mm', () async {
      adapter.body = <String, dynamic>{};

      await repo.createSchedule(
        clientId: 7,
        templateId: 100,
        recurrence: ScheduleRecurrence.once,
        daysOfWeek: const [],
        startDate: DateTime(2026, 8, 3),
        endDate: DateTime(2026, 8, 3),
        timeOfDay: const ScheduleTime(7, 5),
      );

      expect((adapter.bodies.single as Map)['timeOfDay'], '07:05');
    });
  });

  group('reading', () {
    test('reads a client\'s schedules, rule and counts together', () async {
      adapter.body = [
        {
          'id': 3,
          'clientId': 7,
          'templateId': 100,
          'templateName': 'Push day',
          'recurrence': 'WEEKLY',
          'daysOfWeek': ['MONDAY', 'THURSDAY'],
          'timeOfDay': '18:00:00',
          'startDate': '2026-08-03',
          'endDate': '2026-10-06',
          'doneCount': 4,
          'missedCount': 1,
          'remainingCount': 13,
          'cancelledAt': null,
        },
      ];

      final schedules = await repo.findSchedulesForClient(7);

      expect(adapter.paths.single, '/trainer/clients/7/schedules');
      final schedule = schedules.single;
      expect(schedule.recurrence, ScheduleRecurrence.weekly);
      expect(schedule.daysOfWeek,
          [ScheduleWeekday.monday, ScheduleWeekday.thursday]);
      // LocalTime arrives with seconds; the UI only ever wants HH:mm.
      expect(schedule.timeOfDay, const ScheduleTime(18, 0));
      expect(schedule.isCancelled, isFalse);
      expect(schedule.remainingCount, 13);
    });

    test('a cancelled series is still readable', () async {
      adapter.body = [
        {
          'id': 3,
          'clientId': 7,
          'templateId': 100,
          'templateName': 'Push day',
          'recurrence': 'ONCE',
          'daysOfWeek': <Object>[],
          'timeOfDay': null,
          'startDate': '2026-08-03',
          'endDate': '2026-08-03',
          'cancelledAt': '2026-08-01T10:00:00Z',
        },
      ];

      final schedule = (await repo.findSchedulesForClient(7)).single;

      expect(schedule.isCancelled, isTrue);
      expect(schedule.timeOfDay, isNull);
    });

    test('the trainer calendar reads every client in one range', () async {
      adapter.body = [
        {
          'sessionId': 55,
          'clientId': 7,
          'clientEmail': 'anna@example.com',
          'scheduledFor': '2026-08-05',
          'scheduledTime': '18:00',
          'templateName': 'Push day',
          'status': 'UPCOMING',
          'scheduleId': 3,
          'programAssignmentId': null,
          'programName': null,
        },
      ];

      final sessions = await repo.findOccurrences(
        from: DateTime(2026, 8, 3),
        to: DateTime(2026, 8, 9),
      );

      expect(adapter.paths.single, '/trainer/scheduled-sessions');
      expect(adapter.queries.single, {'from': '2026-08-03', 'to': '2026-08-09'});
      final session = sessions.single;
      expect(session.clientId, 7);
      expect(session.status, OccurrenceStatus.upcoming);
      expect(session.isCancellable, isTrue);
      expect(session.isFromProgram, isFalse);
      // A bare LocalDate is read as UTC midnight, like everywhere else.
      expect(session.scheduledFor, DateTime.utc(2026, 8, 5));
    });

    test('an occurrence from a program names its program instead', () async {
      adapter.body = [
        {
          'sessionId': 56,
          'clientId': 7,
          'scheduledFor': '2026-08-06',
          'status': 'DONE',
          'scheduleId': null,
          'programAssignmentId': 9,
          'programName': '12-week base',
        },
      ];

      final session = (await repo.findOccurrences(
        from: DateTime(2026, 8, 3),
        to: DateTime(2026, 8, 9),
      ))
          .single;

      expect(session.isFromProgram, isTrue);
      expect(session.programName, '12-week base');
      // Already done — the peek sheet must not offer to cancel it.
      expect(session.isCancellable, isFalse);
    });

    test('an unknown status does not crash the parse', () async {
      adapter.body = [
        {
          'sessionId': 57,
          'scheduledFor': '2026-08-06',
          'status': 'RESCHEDULED_SOMEDAY',
        },
      ];

      final session = (await repo.findOccurrences(
        from: DateTime(2026, 8, 3),
        to: DateTime(2026, 8, 9),
      ))
          .single;

      expect(session.status, OccurrenceStatus.upcoming);
    });
  });

  group('cancelling', () {
    test('a series goes by schedule id', () async {
      adapter.body = <Object>[];

      await repo.cancelSchedule(3);

      expect(adapter.methods.single, 'DELETE');
      expect(adapter.paths.single, '/trainer/schedules/3');
    });

    test('one occurrence goes by session id — a different endpoint', () async {
      adapter.body = <Object>[];

      await repo.cancelOccurrence(55);

      expect(adapter.methods.single, 'DELETE');
      expect(adapter.paths.single, '/trainer/scheduled-sessions/55');
    });
  });

  group('agenda ordering', () {
    CalendarSession session(int id, {ScheduleTime? at, int day = 5}) =>
        CalendarSession(
          sessionId: id,
          scheduledFor: DateTime(2026, 8, day),
          scheduledTime: at,
          status: OccurrenceStatus.upcoming,
        );

    test('timed sessions come first, in clock order', () {
      final ordered = sessionsOfDay(
        [
          session(1, at: const ScheduleTime(18, 30)),
          session(2, at: const ScheduleTime(7, 0)),
          session(3, at: const ScheduleTime(18, 0)),
        ],
        DateTime(2026, 8, 5),
      );

      expect(ordered.map((s) => s.sessionId), [2, 3, 1]);
    });

    test('untimed sessions sort to the end of the day', () {
      final ordered = sessionsOfDay(
        [
          session(1),
          session(2, at: const ScheduleTime(9, 0)),
          session(3),
        ],
        DateTime(2026, 8, 5),
      );

      expect(ordered.first.sessionId, 2);
      expect(ordered.skip(1).map((s) => s.sessionId), [1, 3]);
    });

    test('another day\'s sessions are not in it', () {
      final ordered = sessionsOfDay(
        [session(1, day: 5), session(2, day: 6)],
        DateTime(2026, 8, 5),
      );

      expect(ordered.map((s) => s.sessionId), [1]);
    });
  });

  group('week arithmetic', () {
    test('a week starts on Monday, whichever day you ask about', () {
      // 2026-08-05 is a Wednesday; 2026-08-09 the Sunday after it.
      expect(weekStartOf(DateTime(2026, 8, 5)), DateTime(2026, 8, 3));
      expect(weekStartOf(DateTime(2026, 8, 9)), DateTime(2026, 8, 3));
      expect(weekStartOf(DateTime(2026, 8, 10)), DateTime(2026, 8, 10));
    });

    test('the time of day is dropped', () {
      expect(weekStartOf(DateTime(2026, 8, 5, 23, 59)), DateTime(2026, 8, 3));
    });
  });
}
