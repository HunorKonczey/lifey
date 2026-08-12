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

      final result = await service.start(
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

      expect(result.started, isFalse);
      expect(result.status, WorkoutSessionNotifierStatus.unavailable);
      expect(result.activityId, isNull);
      expect(calls, isEmpty);
    });

    test('start sends sessionClientId/title/startedAtEpochMs + state and returns the activity id', () async {
      setHandler((call) async {
        calls.add(call);
        return 'native-activity-id';
      });
      final service = WorkoutSessionNotifierService(isAvailable: true, useAndroidBranch: false);

      final result = await service.start(
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

      expect(result.activityId, 'native-activity-id');
      expect(result.started, isTrue);
      expect(result.shouldRetry, isFalse);
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
          'nextSetWeight': null,
          'nextSetReps': null,
          'setsDoneExerciseIndex': null,
          'setsDonePerExercise': null,
          'removedExerciseIndexes': null,
          'sessionPlan': null,
          'setsDoneExerciseId': null,
          'kind': 'STRENGTH',
          'activityType': null,
          'cardio': null,
        },
      });
    });

    test('a refused ActivityKit request is retryable, never a silent success', () async {
      // LiveActivityChannel throws this when Activity.request fails — most
      // often because the app is in the background, which is exactly when a
      // set logged on the watch persists the session.
      setHandler((call) async {
        calls.add(call);
        throw PlatformException(code: 'start_failed', message: 'visibility');
      });
      final service = WorkoutSessionNotifierService(isAvailable: true, useAndroidBranch: false);

      final result = await service.start(
        sessionClientId: 'session-1',
        title: 'Edzés',
        startedAt: DateTime(2026, 7, 10, 8),
        startedLabel: 'Kezdés',
        state: const WorkoutSessionState(exerciseName: 'x', setsDone: 0, totalSetsDone: 0),
      );

      expect(result.started, isFalse);
      expect(result.shouldRetry, isTrue);
      expect(calls, hasLength(1));
    });

    test('Live Activities switched off is not retried', () async {
      setHandler((call) async {
        throw PlatformException(code: 'activities_disabled');
      });
      final service = WorkoutSessionNotifierService(isAvailable: true, useAndroidBranch: false);

      final result = await service.start(
        sessionClientId: 'session-1',
        title: 'Edzés',
        startedAt: DateTime(2026, 7, 10, 8),
        startedLabel: 'Kezdés',
        state: const WorkoutSessionState(exerciseName: 'x', setsDone: 0, totalSetsDone: 0),
      );

      expect(result.status, WorkoutSessionNotifierStatus.unavailable);
      expect(result.shouldRetry, isFalse);
    });

    test('an OS without ActivityKit content (null id, no error) is not retried', () async {
      setHandler((call) async => null);
      final service = WorkoutSessionNotifierService(isAvailable: true, useAndroidBranch: false);

      final result = await service.start(
        sessionClientId: 'session-1',
        title: 'Edzés',
        startedAt: DateTime(2026, 7, 10, 8),
        startedLabel: 'Kezdés',
        state: const WorkoutSessionState(exerciseName: 'x', setsDone: 0, totalSetsDone: 0),
      );

      expect(result.status, WorkoutSessionNotifierStatus.unavailable);
      expect(result.activityId, isNull);
    });

    test('a missing native handler is swallowed, not rethrown', () async {
      setHandler((call) async {
        throw MissingPluginException('no handler');
      });
      final service = WorkoutSessionNotifierService(isAvailable: true, useAndroidBranch: false);

      final result = await service.start(
        sessionClientId: 'session-1',
        title: 'Edzés',
        startedAt: DateTime(2026, 7, 10, 8),
        startedLabel: 'Kezdés',
        state: const WorkoutSessionState(exerciseName: 'x', setsDone: 0, totalSetsDone: 0),
      );

      expect(result.status, WorkoutSessionNotifierStatus.unavailable);
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
          'nextSetWeight': null,
          'nextSetReps': null,
          'setsDoneExerciseIndex': null,
          'setsDonePerExercise': null,
          'removedExerciseIndexes': null,
          'sessionPlan': null,
          'setsDoneExerciseId': null,
          'kind': 'STRENGTH',
          'activityType': null,
          'cardio': null,
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
          'nextSetWeight': null,
          'nextSetReps': null,
          'setsDoneExerciseIndex': null,
          'setsDonePerExercise': null,
          'removedExerciseIndexes': null,
          'sessionPlan': null,
          'setsDoneExerciseId': null,
          'kind': 'STRENGTH',
          'activityType': null,
          'cardio': null,
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
          bool usesChronometer = true,
        }) async {
          showCalls++;
        },
      );

      final result = await service.start(
        sessionClientId: 'session-1',
        title: 'Push Day',
        startedAt: DateTime(2026, 7, 10, 18, 5),
        startedLabel: 'Started',
        state: const WorkoutSessionState(exerciseName: 'Bench Press', setsDone: 0, totalSetsDone: 0),
      );

      expect(result.started, isFalse);
      expect(result.status, WorkoutSessionNotifierStatus.unavailable);
      expect(permissionCalls, 0);
      expect(showCalls, 0);
    });

    test('start reports success once the notification is shown', () async {
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
          bool usesChronometer = true,
        }) async {},
      );

      final result = await service.start(
        sessionClientId: 'session-1',
        title: 'Push Day',
        startedAt: DateTime(2026, 7, 10, 18, 5),
        startedLabel: 'Started',
        state: const WorkoutSessionState(exerciseName: 'Bench Press', setsDone: 0, totalSetsDone: 0),
      );

      // Android has no activity id, so "started" is the only signal callers
      // get — before this it was indistinguishable from a denied permission.
      expect(result.started, isTrue);
      expect(result.activityId, isNull);
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
          bool usesChronometer = true,
        }) async {
          showCalls++;
        },
      );

      final result = await service.start(
        sessionClientId: 'session-1',
        title: 'Push Day',
        startedAt: DateTime(2026, 7, 10, 18, 5),
        startedLabel: 'Started',
        state: const WorkoutSessionState(exerciseName: 'Bench Press', setsDone: 0, totalSetsDone: 0),
      );

      expect(result.started, isFalse);
      expect(result.status, WorkoutSessionNotifierStatus.unavailable);
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
          bool usesChronometer = true,
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
          bool usesChronometer = true,
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
          bool usesChronometer = true,
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
          bool usesChronometer = true,
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

    test('a CARDIO state renders a metrics body, dropping "—" placeholders (no "0 sets")', () async {
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
          bool usesChronometer = true,
        }) async {
          capturedBody = body;
        },
      );

      await service.start(
        sessionClientId: 'cardio-1',
        title: 'Futás',
        startedAt: DateTime(2026, 8, 12, 7),
        startedLabel: 'Elkezdve',
        state: const WorkoutSessionState(
          exerciseName: 'Futás — 5,24 km',
          setsDone: 0,
          setsTotal: null,
          totalSetsDone: 0,
          kind: 'CARDIO',
          activityType: 'RUNNING',
          cardio: CardioLiveMetrics(
            primaryLabel: 'DISTANCE',
            primaryValue: '5,24 km',
            secondaryLabel: 'MOVING TIME',
            secondaryValue: '28:14',
            tertiaryLabel: 'PACE',
            tertiaryValue: '5:23 /km',
            paused: false,
            movingSecondsBase: 1694,
            movingSinceEpochMs: 1783075260000,
          ),
        ),
      );

      expect(capturedBody, '5,24 km · 28:14 · 5:23 /km');
      expect(capturedBody, isNot(contains('—')));
    });

    test('a running CARDIO session ticks the chronometer from the moving-time checkpoint', () async {
      int? capturedWhenEpochMs;
      bool? capturedUsesChronometer;
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
          bool usesChronometer = true,
        }) async {
          capturedWhenEpochMs = whenEpochMs;
          capturedUsesChronometer = usesChronometer;
        },
      );

      // movingSecondsBase=100 accrued before this checkpoint, ticking live
      // since movingSinceEpochMs — `when` shifts back by the base so
      // Android's single "now - when" chronometer renders base + live.
      await service.start(
        sessionClientId: 'cardio-1',
        title: 'Futás',
        startedAt: DateTime(2026, 8, 12, 7),
        startedLabel: 'Elkezdve',
        state: const WorkoutSessionState(
          exerciseName: 'Futás — 5,24 km',
          setsDone: 0,
          totalSetsDone: 0,
          kind: 'CARDIO',
          activityType: 'RUNNING',
          cardio: CardioLiveMetrics(
            primaryLabel: 'DISTANCE',
            primaryValue: '5,24 km',
            paused: false,
            movingSecondsBase: 100,
            movingSinceEpochMs: 1783075260000,
          ),
        ),
      );

      expect(capturedWhenEpochMs, 1783075260000 - 100000);
      expect(capturedUsesChronometer, isTrue);
    });

    test('a paused CARDIO session turns the chronometer off — it must not keep ticking', () async {
      bool? capturedUsesChronometer;
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
          bool usesChronometer = true,
        }) async {
          capturedUsesChronometer = usesChronometer;
          capturedBody = body;
        },
      );

      await service.start(
        sessionClientId: 'cardio-1',
        title: 'Futás',
        startedAt: DateTime(2026, 8, 12, 7),
        startedLabel: 'Elkezdve',
        state: const WorkoutSessionState(
          exerciseName: 'Futás — 42:18',
          setsDone: 0,
          totalSetsDone: 0,
          kind: 'CARDIO',
          activityType: 'RUNNING',
          cardio: CardioLiveMetrics(
            primaryLabel: 'MOVING TIME',
            primaryValue: '42:18',
            paused: true,
            movingSecondsBase: 2538,
          ),
        ),
      );

      expect(capturedUsesChronometer, isFalse);
      expect(capturedBody, '42:18');
    });

    test('two updates with identical content only render once ("frissítés csak változásra")', () async {
      var showCalls = 0;
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
          bool usesChronometer = true,
        }) async {
          showCalls++;
        },
      );
      const state = WorkoutSessionState(
        exerciseName: 'Bench Press',
        setsDone: 2,
        setsTotal: 4,
        totalSetsDone: 2,
        lastSetAtEpochMs: 1783075260000,
      );

      await service.start(
        sessionClientId: 'session-1',
        title: 'Push Day',
        startedAt: DateTime(2026, 7, 10, 18, 5),
        startedLabel: 'Started',
        state: state,
      );
      showCalls = 0; // isolate the repeated update() below
      await service.update(sessionClientId: 'session-1', startedLabel: 'Started', state: state);
      await service.update(sessionClientId: 'session-1', startedLabel: 'Started', state: state);

      expect(showCalls, 0);
    });

    test('a changed update after a run of identical ones renders again', () async {
      final bodies = <String>[];
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
          bool usesChronometer = true,
        }) async {
          bodies.add(body);
        },
      );
      const state = WorkoutSessionState(
        exerciseName: 'Bench Press',
        setsDone: 2,
        setsTotal: 4,
        totalSetsDone: 2,
      );

      await service.start(
        sessionClientId: 'session-1',
        title: 'Push Day',
        startedAt: DateTime(2026, 7, 10, 18, 5),
        startedLabel: 'Started',
        state: state,
      );
      await service.update(sessionClientId: 'session-1', startedLabel: 'Started', state: state);
      await service.update(
        sessionClientId: 'session-1',
        startedLabel: 'Started',
        state: const WorkoutSessionState(
          exerciseName: 'Bench Press',
          setsDone: 3,
          setsTotal: 4,
          totalSetsDone: 3,
        ),
      );

      expect(bodies, ['Bench Press · 2/4', 'Bench Press · 3/4']);
    });

    test('a new session starting with content identical to the last one still renders', () async {
      var showCalls = 0;
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
          bool usesChronometer = true,
        }) async {
          showCalls++;
        },
      );
      const state = WorkoutSessionState(exerciseName: 'Bench Press', setsDone: 0, totalSetsDone: 0);

      await service.start(
        sessionClientId: 'session-1',
        title: 'Push Day',
        startedAt: DateTime(2026, 7, 10, 18, 5),
        startedLabel: 'Started',
        state: state,
      );
      await service.end();
      await service.start(
        sessionClientId: 'session-2',
        title: 'Push Day',
        startedAt: DateTime(2026, 7, 10, 18, 5),
        startedLabel: 'Started',
        state: state,
      );

      expect(showCalls, 2);
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
          bool usesChronometer = true,
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

  group('WorkoutSessionState / CardioLiveMetrics — cardio payload shape (C2.9)', () {
    test('kind defaults to STRENGTH — every pre-C2.9 construction keeps meaning what it did', () {
      const state = WorkoutSessionState(exerciseName: 'Fekvenyomás', setsDone: 1, totalSetsDone: 1);

      expect(state.kind, 'STRENGTH');
      expect(state.activityType, isNull);
      expect(state.cardio, isNull);
      expect(state.toJson()['kind'], 'STRENGTH');
    });

    test('a CARDIO state carries activityType + a full CardioLiveMetrics block', () {
      const cardio = CardioLiveMetrics(
        primaryLabel: 'DISTANCE',
        primaryValue: '5.24 km',
        secondaryLabel: 'MOVING TIME',
        secondaryValue: '28:14',
        tertiaryLabel: 'PACE',
        tertiaryValue: '5:23 /km',
        paused: false,
        movingSecondsBase: 1694,
        movingSinceEpochMs: 1783075260000,
      );
      const state = WorkoutSessionState(
        exerciseName: 'Futás — 5.24 km',
        setsDone: 0,
        totalSetsDone: 0,
        kind: 'CARDIO',
        activityType: 'RUNNING',
        cardio: cardio,
      );

      expect(state.toJson(), {
        'exerciseName': 'Futás — 5.24 km',
        'setsDone': 0,
        'setsTotal': null,
        'totalSetsDone': 0,
        'lastSetAtEpochMs': null,
        'restEndsAtEpochMs': null,
        'restTotalSeconds': null,
        'restRemainingSeconds': null,
        'nextSetWeight': null,
        'nextSetReps': null,
        'setsDoneExerciseIndex': null,
        'setsDonePerExercise': null,
        'removedExerciseIndexes': null,
        'sessionPlan': null,
        'setsDoneExerciseId': null,
        'kind': 'CARDIO',
        'activityType': 'RUNNING',
        'cardio': {
          'primaryLabel': 'DISTANCE',
          'primaryValue': '5.24 km',
          'secondaryLabel': 'MOVING TIME',
          'secondaryValue': '28:14',
          'tertiaryLabel': 'PACE',
          'tertiaryValue': '5:23 /km',
          'paused': false,
          'movingSecondsBase': 1694,
          'movingSinceEpochMs': 1783075260000,
        },
      });
    });

    test('a paused CardioLiveMetrics has no movingSinceEpochMs', () {
      const cardio = CardioLiveMetrics(
        primaryLabel: 'MOVING TIME',
        primaryValue: '42:18',
        paused: true,
        movingSecondsBase: 2538,
      );

      expect(cardio.toJson()['paused'], isTrue);
      expect(cardio.toJson()['movingSinceEpochMs'], isNull);
    });

    test('a CARDIO start() call over the iOS channel sends the cardio block', () async {
      const channel = MethodChannel('lifey/live_activity');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return 'activity-1';
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      final service = WorkoutSessionNotifierService(isAvailable: true, useAndroidBranch: false);

      await service.start(
        sessionClientId: 'cardio-1',
        title: 'Futás',
        startedAt: DateTime(2026, 8, 12, 7),
        startedLabel: 'Elkezdve',
        state: const WorkoutSessionState(
          exerciseName: 'Futás — 5.24 km',
          setsDone: 0,
          setsTotal: null,
          totalSetsDone: 0,
          kind: 'CARDIO',
          activityType: 'RUNNING',
          cardio: CardioLiveMetrics(
            primaryLabel: 'DISTANCE',
            primaryValue: '5.24 km',
            paused: false,
            movingSinceEpochMs: 1783075260000,
          ),
        ),
      );

      final sentState = calls.single.arguments['state'] as Map;
      // The legacy fields an old build (that has never heard of `kind`)
      // reads: a real name, and no "0/0" fraction — the C2.9 kész-ha.
      expect(sentState['exerciseName'], 'Futás — 5.24 km');
      expect(sentState['setsTotal'], isNull);
      expect(sentState['kind'], 'CARDIO');
      expect((sentState['cardio'] as Map)['primaryValue'], '5.24 km');
    });
  });
}
