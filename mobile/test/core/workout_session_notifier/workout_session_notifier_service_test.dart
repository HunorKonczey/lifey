import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/workout_session_notifier/workout_session_notifier_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkoutSessionNotifierService (iOS branch, MethodChannel)', () {
    const channel = MethodChannel('lifey/live_activity');
    final calls = <MethodCall>[];

    void setHandler(Future<Object?> Function(MethodCall) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, handler);
    }

    setUp(() {
      calls.clear();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('no-ops when unavailable — no channel calls made', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WorkoutSessionNotifierService(isAvailable: false, useAndroidBranch: false);

      final id = await service.start(
        sessionClientId: 'session-1',
        title: 'Edzés',
        startedAt: DateTime(2026, 7, 10, 8),
        startedLabel: 'Kezdés',
        state: const WorkoutSessionState(
          exerciseName: 'Fekvenyomás',
          setsDone: 1,
          setsTotal: 3,
          totalSetsDone: 1,
          lastSetAtEpochMs: 1000,
        ),
      );
      await service.update(
        sessionClientId: 'session-1',
        startedLabel: 'Kezdés',
        state: const WorkoutSessionState(exerciseName: 'x', setsDone: 0, totalSetsDone: 0),
      );
      await service.end();
      await service.endAll();

      expect(id, isNull);
      expect(calls, isEmpty);
    });

    test('start sends sessionClientId/title/startedAtEpochMs + state and returns the activity id', () async {
      setHandler((call) async {
        calls.add(call);
        return 'native-activity-id';
      });
      final service = WorkoutSessionNotifierService(isAvailable: true, useAndroidBranch: false);

      final id = await service.start(
        sessionClientId: 'session-1',
        title: 'Edzés',
        startedAt: DateTime.fromMillisecondsSinceEpoch(1783075200000),
        startedLabel: 'Kezdés',
        state: const WorkoutSessionState(
          exerciseName: 'Fekvenyomás',
          setsDone: 1,
          setsTotal: 3,
          totalSetsDone: 1,
          lastSetAtEpochMs: 1783075260000,
        ),
      );

      expect(id, 'native-activity-id');
      expect(calls, hasLength(1));
      expect(calls.single.method, 'start');
      expect(calls.single.arguments, {
        'sessionClientId': 'session-1',
        'title': 'Edzés',
        'startedAtEpochMs': 1783075200000,
        'state': {
          'exerciseName': 'Fekvenyomás',
          'setsDone': 1,
          'setsTotal': 3,
          'totalSetsDone': 1,
          'lastSetAtEpochMs': 1783075260000,
          'restEndsAtEpochMs': null,
          'restTotalSeconds': null,
          'restRemainingSeconds': null,
        },
      });
    });

    test('update sends sessionClientId + state', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WorkoutSessionNotifierService(isAvailable: true, useAndroidBranch: false);

      await service.update(
        sessionClientId: 'session-1',
        startedLabel: 'Kezdés',
        state: const WorkoutSessionState(
          exerciseName: 'Guggolás',
          setsDone: 2,
          setsTotal: null,
          totalSetsDone: 5,
          lastSetAtEpochMs: null,
        ),
      );

      expect(calls.single.method, 'update');
      expect(calls.single.arguments, {
        'sessionClientId': 'session-1',
        'state': {
          'exerciseName': 'Guggolás',
          'setsDone': 2,
          'setsTotal': null,
          'totalSetsDone': 5,
          'lastSetAtEpochMs': null,
          'restEndsAtEpochMs': null,
          'restTotalSeconds': null,
          'restRemainingSeconds': null,
        },
      });
    });

    test('end and endAll invoke their methods with no arguments', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WorkoutSessionNotifierService(isAvailable: true, useAndroidBranch: false);

      await service.end();
      await service.endAll();

      expect(calls.map((c) => c.method), ['end', 'endAll']);
    });

    test('update state JSON carries restEndsAtEpochMs when present (docs/39-rest-timer-plan.md, Prompt 5)',
        () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = WorkoutSessionNotifierService(isAvailable: true, useAndroidBranch: false);

      await service.update(
        sessionClientId: 'session-1',
        startedLabel: 'Kezdés',
        state: const WorkoutSessionState(
          exerciseName: 'Guggolás',
          setsDone: 2,
          setsTotal: 4,
          totalSetsDone: 2,
          lastSetAtEpochMs: 1783075260000,
          restEndsAtEpochMs: 1783075350000,
        ),
      );

      expect(calls.single.arguments, {
        'sessionClientId': 'session-1',
        'state': {
          'exerciseName': 'Guggolás',
          'setsDone': 2,
          'setsTotal': 4,
          'totalSetsDone': 2,
          'lastSetAtEpochMs': 1783075260000,
          'restEndsAtEpochMs': 1783075350000,
          'restTotalSeconds': null,
          'restRemainingSeconds': null,
        },
      });
    });

    test('a full session call sequence: start -> update -> end', () async {
      setHandler((call) async {
        calls.add(call);
        return call.method == 'start' ? 'activity-1' : null;
      });
      final service = WorkoutSessionNotifierService(isAvailable: true, useAndroidBranch: false);

      await service.start(
        sessionClientId: 'session-1',
        title: 'Edzés',
        startedAt: DateTime(2026, 7, 10, 8),
        startedLabel: 'Kezdés',
        state: const WorkoutSessionState(
            exerciseName: 'Fekvenyomás', setsDone: 0, setsTotal: 3, totalSetsDone: 0),
      );
      await service.update(
        sessionClientId: 'session-1',
        startedLabel: 'Kezdés',
        state: const WorkoutSessionState(
            exerciseName: 'Fekvenyomás',
            setsDone: 1,
            setsTotal: 3,
            totalSetsDone: 1,
            lastSetAtEpochMs: 1000),
      );
      await service.end();

      expect(calls.map((c) => c.method), ['start', 'update', 'end']);
    });
  });

  group('WorkoutSessionNotifierService (Android branch, ongoing notification)', () {
    test('no-ops and requests no permission when unavailable', () async {
      var permissionCalls = 0;
      var showCalls = 0;
      final service = WorkoutSessionNotifierService(
        isAvailable: false,
        useAndroidBranch: true,
        requestAndroidPermission: () async {
          permissionCalls++;
          return true;
        },
        showAndroidNotification: ({
          required title,
          required body,
          required subText,
          required whenEpochMs,
          bool chronometerCountDown = false,
        }) async {
          showCalls++;
        },
      );

      final id = await service.start(
        sessionClientId: 'session-1',
        title: 'Push Day',
        startedAt: DateTime(2026, 7, 10, 18, 5),
        startedLabel: 'Started',
        state: const WorkoutSessionState(exerciseName: 'Bench Press', setsDone: 0, totalSetsDone: 0),
      );

      expect(id, isNull);
      expect(permissionCalls, 0);
      expect(showCalls, 0);
    });

    test('start requests permission and, when denied, never shows the notification', () async {
      var showCalls = 0;
      final service = WorkoutSessionNotifierService(
        isAvailable: true,
        useAndroidBranch: true,
        requestAndroidPermission: () async => false,
        showAndroidNotification: ({
          required title,
          required body,
          required subText,
          required whenEpochMs,
          bool chronometerCountDown = false,
        }) async {
          showCalls++;
        },
      );

      final id = await service.start(
        sessionClientId: 'session-1',
        title: 'Push Day',
        startedAt: DateTime(2026, 7, 10, 18, 5),
        startedLabel: 'Started',
        state: const WorkoutSessionState(exerciseName: 'Bench Press', setsDone: 0, totalSetsDone: 0),
      );

      expect(id, isNull);
      expect(showCalls, 0);
    });

    test('start shows a notification anchored to startedAt before any set is logged', () async {
      String? capturedTitle, capturedBody, capturedSubText;
      int? capturedWhenEpochMs;
      final service = WorkoutSessionNotifierService(
        isAvailable: true,
        useAndroidBranch: true,
        requestAndroidPermission: () async => true,
        showAndroidNotification: ({
          required title,
          required body,
          required subText,
          required whenEpochMs,
          bool chronometerCountDown = false,
        }) async {
          capturedTitle = title;
          capturedBody = body;
          capturedSubText = subText;
          capturedWhenEpochMs = whenEpochMs;
        },
      );

      final startedAt = DateTime(2026, 7, 10, 18, 5);
      await service.start(
        sessionClientId: 'session-1',
        title: 'Push Day',
        startedAt: startedAt,
        startedLabel: 'Started',
        state: const WorkoutSessionState(exerciseName: 'Bench Press', setsDone: 0, setsTotal: 4, totalSetsDone: 0),
      );

      expect(capturedTitle, 'Push Day');
      expect(capturedBody, 'Bench Press · 0/4');
      expect(capturedSubText, 'Started 18:05');
      expect(capturedWhenEpochMs, startedAt.millisecondsSinceEpoch);
    });

    test('update after a logged set anchors the chronometer to lastSetAtEpochMs (rest count-up)', () async {
      int? capturedWhenEpochMs;
      String? capturedBody;
      final service = WorkoutSessionNotifierService(
        isAvailable: true,
        useAndroidBranch: true,
        requestAndroidPermission: () async => true,
        showAndroidNotification: ({
          required title,
          required body,
          required subText,
          required whenEpochMs,
          bool chronometerCountDown = false,
        }) async {
          capturedBody = body;
          capturedWhenEpochMs = whenEpochMs;
        },
      );

      final startedAt = DateTime(2026, 7, 10, 18, 5);
      await service.start(
        sessionClientId: 'session-1',
        title: 'Push Day',
        startedAt: startedAt,
        startedLabel: 'Started',
        state: const WorkoutSessionState(exerciseName: 'Bench Press', setsDone: 0, setsTotal: 4, totalSetsDone: 0),
      );

      final lastSetAt = DateTime(2026, 7, 10, 18, 12);
      await service.update(
        sessionClientId: 'session-1',
        startedLabel: 'Started',
        state: WorkoutSessionState(
          exerciseName: 'Bench Press',
          setsDone: 2,
          setsTotal: 4,
          totalSetsDone: 2,
          lastSetAtEpochMs: lastSetAt.millisecondsSinceEpoch,
        ),
      );

      expect(capturedBody, 'Bench Press · 2/4');
      expect(capturedWhenEpochMs, lastSetAt.millisecondsSinceEpoch);
    });

    test('update with a future restEndsAtEpochMs anchors the chronometer to it in count-down mode '
        '(docs/39-rest-timer-plan.md, Prompt 5)', () async {
      int? capturedWhenEpochMs;
      bool? capturedCountDown;
      final service = WorkoutSessionNotifierService(
        isAvailable: true,
        useAndroidBranch: true,
        requestAndroidPermission: () async => true,
        showAndroidNotification: ({
          required title,
          required body,
          required subText,
          required whenEpochMs,
          bool chronometerCountDown = false,
        }) async {
          capturedWhenEpochMs = whenEpochMs;
          capturedCountDown = chronometerCountDown;
        },
      );

      // Anchored to the real clock (not a fixed 2026 date like the sibling
      // tests) — the countdown-vs-count-up decision compares restEndsAt
      // against DateTime.now(), so it must actually be in the future when
      // this test runs.
      final startedAt = DateTime.now().subtract(const Duration(minutes: 10));
      await service.start(
        sessionClientId: 'session-1',
        title: 'Push Day',
        startedAt: startedAt,
        startedLabel: 'Started',
        state: const WorkoutSessionState(exerciseName: 'Bench Press', setsDone: 0, setsTotal: 4, totalSetsDone: 0),
      );

      final lastSetAt = DateTime.now().subtract(const Duration(minutes: 1));
      final restEndsAt = DateTime.now().add(const Duration(minutes: 5));
      await service.update(
        sessionClientId: 'session-1',
        startedLabel: 'Started',
        state: WorkoutSessionState(
          exerciseName: 'Bench Press',
          setsDone: 2,
          setsTotal: 4,
          totalSetsDone: 2,
          lastSetAtEpochMs: lastSetAt.millisecondsSinceEpoch,
          restEndsAtEpochMs: restEndsAt.millisecondsSinceEpoch,
        ),
      );

      expect(capturedWhenEpochMs, restEndsAt.millisecondsSinceEpoch);
      expect(capturedCountDown, isTrue);
    });

    test('update with a restEndsAtEpochMs already in the past falls back to the plain rest count-up',
        () async {
      int? capturedWhenEpochMs;
      bool? capturedCountDown;
      final service = WorkoutSessionNotifierService(
        isAvailable: true,
        useAndroidBranch: true,
        requestAndroidPermission: () async => true,
        showAndroidNotification: ({
          required title,
          required body,
          required subText,
          required whenEpochMs,
          bool chronometerCountDown = false,
        }) async {
          capturedWhenEpochMs = whenEpochMs;
          capturedCountDown = chronometerCountDown;
        },
      );

      final startedAt = DateTime(2026, 7, 10, 18, 5);
      await service.start(
        sessionClientId: 'session-1',
        title: 'Push Day',
        startedAt: startedAt,
        startedLabel: 'Started',
        state: const WorkoutSessionState(exerciseName: 'Bench Press', setsDone: 0, setsTotal: 4, totalSetsDone: 0),
      );

      final lastSetAt = DateTime(2026, 7, 10, 18, 12);
      final expiredRestEnd = DateTime(2000, 1, 1); // already in the past
      await service.update(
        sessionClientId: 'session-1',
        startedLabel: 'Started',
        state: WorkoutSessionState(
          exerciseName: 'Bench Press',
          setsDone: 2,
          setsTotal: 4,
          totalSetsDone: 2,
          lastSetAtEpochMs: lastSetAt.millisecondsSinceEpoch,
          restEndsAtEpochMs: expiredRestEnd.millisecondsSinceEpoch,
        ),
      );

      expect(capturedWhenEpochMs, lastSetAt.millisecondsSinceEpoch);
      expect(capturedCountDown, isFalse);
    });

    test('end and endAll cancel the notification', () async {
      var cancelCalls = 0;
      final service = WorkoutSessionNotifierService(
        isAvailable: true,
        useAndroidBranch: true,
        requestAndroidPermission: () async => true,
        showAndroidNotification: ({
          required title,
          required body,
          required subText,
          required whenEpochMs,
          bool chronometerCountDown = false,
        }) async {},
        cancelAndroidNotification: () async {
          cancelCalls++;
        },
      );

      await service.end();
      await service.endAll();

      expect(cancelCalls, 2);
    });

    test('endAll on app start with no in-progress session cancels an orphaned notification', () async {
      var cancelCalls = 0;
      final service = WorkoutSessionNotifierService(
        isAvailable: true,
        useAndroidBranch: true,
        cancelAndroidNotification: () async {
          cancelCalls++;
        },
      );

      await service.endAll();

      expect(cancelCalls, 1);
    });
  });
}
