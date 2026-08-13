import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/location/location_service.dart';
import 'package:lifey/core/location/location_service_geolocator.dart';
import 'package:lifey/core/watch/watch_workout_service.dart';
import 'package:lifey/core/workout_session_notifier/workout_session_notifier_service.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_session_screen.dart';
import 'package:lifey/features/workouts/presentation/cardio_summary_screen.dart';
import 'package:lifey/features/workouts/presentation/workouts_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// C2.1: `CardioSessionScreen` — the live state machine skeleton.
/// docs/cardio/59-cardio-implementation-plan.md C2.1 — kész-ha: "App-kilövés
/// után az edzés helyreáll a pontos mozgásidővel" (after an app kill, the
/// workout restores with exact moving time).
///
/// C2.5 added pause-reason visuals (manual vs auto, M08/M09) and
/// slide-to-finish (M12) — see the tests from "a plain tap on the
/// slide-to-finish bar" onward.
///
/// The controller is faked at the pause/resume/finish methods themselves —
/// same reasoning as `log_cardio_sheet_test.dart`: those are thin,
/// already-covered passes to the repository, so this file verifies what the
/// *screen* computes and sends.
///
/// Every fixture here uses RUNNING (DISTANCE family) with no distance
/// recorded, so C2.2's DISTANCE layout falls back to exactly the
/// family-agnostic moving-time display these C2.1 tests were written
/// against — see `cardio_session_screen_distance_test.dart` for the
/// distance-present/distance-editing behavior C2.2 actually added.

class _RecordingSessionController extends WorkoutSessionController {
  final pauseCalls = <Map<String, Object?>>[];
  final resumeCalls = <Map<String, Object?>>[];
  final finishCalls = <Map<String, Object?>>[];
  final updateLiveCardioMetricsCalls = <Map<String, Object?>>[];
  bool failNext = false;

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);

  @override
  Future<void> pauseCardioSession(
    String clientId, {
    required DateTime startedAt,
    required int movingSeconds,
  }) async {
    if (failNext) throw Exception('boom');
    pauseCalls.add({'clientId': clientId, 'startedAt': startedAt, 'movingSeconds': movingSeconds});
  }

  @override
  Future<void> resumeCardioSession(
    String clientId, {
    required DateTime startedAt,
    required DateTime resumedAt,
  }) async {
    if (failNext) throw Exception('boom');
    resumeCalls.add({'clientId': clientId, 'startedAt': startedAt, 'resumedAt': resumedAt});
  }

  @override
  Future<void> finishCardioSession(
    String clientId, {
    required DateTime startedAt,
    required DateTime finishedAt,
    required int movingSeconds,
    Value<CardioMetrics?> cardio = const Value.absent(),
    Value<List<CardioSplit>> splits = const Value.absent(),
  }) async {
    if (failNext) throw Exception('boom');
    finishCalls.add({
      'clientId': clientId,
      'startedAt': startedAt,
      'finishedAt': finishedAt,
      'movingSeconds': movingSeconds,
      'cardio': cardio,
      'splits': splits,
    });
  }

  @override
  Future<void> updateLiveCardioMetrics(
    String clientId, {
    required DateTime startedAt,
    required CardioMetrics cardio,
  }) async {
    if (failNext) throw Exception('boom');
    updateLiveCardioMetricsCalls.add({'clientId': clientId, 'startedAt': startedAt, 'cardio': cardio});
  }
}

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

/// This file's fixtures are all DISTANCE-family (see the class doc above),
/// so every test here would otherwise also render C4a.2's "no GPS" status
/// card/chip — pure layout noise for tests that are about pause/resume/
/// finish/Live-Activity payloads, not location. Overriding
/// `locationServiceProvider` with a pre-granted stub keeps `canTrack` true
/// throughout, matching this file's pre-C4a.2 assumptions; the location
/// card itself has its own dedicated tests elsewhere.
LocationServiceStub _grantedLocationStub() => LocationServiceStub(
      initial: const LocationAvailability(
        authorization: LocationAuthorization.granted,
        precise: true,
        serviceEnabled: true,
      ),
    );

WorkoutSession _runningSession({int movingSeconds = 0, required int movingSinceEpochMs}) {
  return WorkoutSession(
    clientId: 'live-1',
    exercises: const [],
    sets: const [],
    startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    sessionKind: 'CARDIO',
    activityType: 'RUNNING',
    movingSeconds: movingSeconds,
    movingSinceEpochMs: movingSinceEpochMs,
  );
}

WorkoutSession _pausedSession({required int movingSeconds}) {
  return WorkoutSession(
    clientId: 'live-1',
    exercises: const [],
    sets: const [],
    startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    sessionKind: 'CARDIO',
    activityType: 'RUNNING',
    movingSeconds: movingSeconds,
  );
}

WorkoutSession _runningMachineSession({required int movingSinceEpochMs}) {
  return WorkoutSession(
    clientId: 'live-machine',
    exercises: const [],
    sets: const [],
    startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
    sessionKind: 'CARDIO',
    activityType: 'INDOOR_BIKE',
    movingSeconds: 0,
    movingSinceEpochMs: movingSinceEpochMs,
  );
}

/// Records `start`/`update`/`end` calls without touching the real
/// MethodChannel — `isAvailable: false` in the constructor already makes
/// the base class a no-op, so overriding all three is purely to observe
/// what `CardioSessionScreen` *would* have sent.
class _RecordingNotifierService extends WorkoutSessionNotifierService {
  _RecordingNotifierService() : super(isAvailable: false);

  final startCalls = <WorkoutSessionState>[];
  final updateCalls = <WorkoutSessionState>[];
  int endCalls = 0;

  @override
  Future<WorkoutSessionNotifierStart> start({
    required String sessionClientId,
    required String title,
    required DateTime startedAt,
    required String startedLabel,
    required WorkoutSessionState state,
  }) async {
    startCalls.add(state);
    return const WorkoutSessionNotifierStart(WorkoutSessionNotifierStatus.started);
  }

  @override
  Future<void> update({
    required String sessionClientId,
    required String startedLabel,
    required WorkoutSessionState state,
  }) async {
    updateCalls.add(state);
  }

  @override
  Future<void> end() async {
    endCalls++;
  }
}

/// The C5.2 counterpart of [_RecordingNotifierService] — records what
/// `CardioSessionScreen` sends the watch bridge, without touching the real
/// MethodChannel.
class _RecordingWatchService extends WatchWorkoutService {
  _RecordingWatchService() : super(isAvailable: false);

  final startCalls = <
      ({
        String sessionClientId,
        String? activityType,
        String? venue,
        WorkoutSessionState state
      })>[];
  final updateCalls = <WorkoutSessionState>[];
  int endCalls = 0;

  @override
  Future<void> startWorkout({
    required String sessionClientId,
    required String title,
    required DateTime startedAt,
    required WorkoutSessionState state,
    String? activityType,
    String? venue,
  }) async {
    startCalls.add((
      sessionClientId: sessionClientId,
      activityType: activityType,
      venue: venue,
      state: state,
    ));
  }

  @override
  Future<void> updateState({
    required String sessionClientId,
    required WorkoutSessionState state,
  }) async {
    updateCalls.add(state);
  }

  @override
  Future<void> endWorkout(String sessionClientId) async {
    endCalls++;
  }
}

/// C4a.3: `CardioSessionScreen.initState` now unconditionally reads
/// `cardioTrackPointRepositoryProvider` (→ `appDatabaseProvider`) for every
/// DISTANCE-family session, to seed its GPS-point sequence counter — see
/// `CardioSessionScreenState._seedTrackPointSeqAndSync`. An in-memory
/// database (the established pattern — see e.g.
/// `test/features/recipes/presentation/log_recipe_sheet_test.dart`) keeps
/// that real, instead of leaving `appDatabaseProvider` to its default (a
/// real on-disk connection Drift then warns about opening repeatedly, once
/// per test in this file).
AppDatabase _testDatabase() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

Future<_RecordingSessionController> _pump(WidgetTester tester, WorkoutSession session) async {
  final controller = _RecordingSessionController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => controller),
        settingsControllerProvider.overrideWith(_MetricSettings.new),
        locationServiceProvider.overrideWithValue(_grantedLocationStub()),
        appDatabaseProvider.overrideWithValue(_testDatabase()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CardioSessionScreen(session: session),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

/// Same as [_pump], plus a [_RecordingNotifierService] override — kept
/// separate rather than folded into [_pump] so the many existing tests that
/// only care about [_RecordingSessionController] don't all have to change
/// shape for a return value they'd never use.
Future<(_RecordingSessionController, _RecordingNotifierService)> _pumpWithNotifier(
  WidgetTester tester,
  WorkoutSession session,
) async {
  final controller = _RecordingSessionController();
  final notifier = _RecordingNotifierService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => controller),
        settingsControllerProvider.overrideWith(_MetricSettings.new),
        workoutSessionNotifierServiceProvider.overrideWithValue(notifier),
        locationServiceProvider.overrideWithValue(_grantedLocationStub()),
        appDatabaseProvider.overrideWithValue(_testDatabase()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CardioSessionScreen(session: session),
      ),
    ),
  );
  await tester.pump();
  return (controller, notifier);
}

/// Same as [_pump], plus a [_RecordingWatchService] override (C5.2) — kept
/// separate from [_pumpWithNotifier] for the same reason that one is kept
/// separate from [_pump].
Future<(_RecordingSessionController, _RecordingWatchService)> _pumpWithWatch(
  WidgetTester tester,
  WorkoutSession session,
) async {
  final controller = _RecordingSessionController();
  final watch = _RecordingWatchService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => controller),
        settingsControllerProvider.overrideWith(_MetricSettings.new),
        watchWorkoutServiceProvider.overrideWithValue(watch),
        locationServiceProvider.overrideWithValue(_grantedLocationStub()),
        appDatabaseProvider.overrideWithValue(_testDatabase()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CardioSessionScreen(session: session),
      ),
    ),
  );
  await tester.pump();
  return (controller, watch);
}

/// Starts a drag gesture on the slide-to-finish bar and moves it to
/// [fraction] of the bar's width — the caller finishes the gesture with
/// `gesture.up()` (below threshold) or leaves it to the caller to decide.
Future<TestGesture> _dragFinishBarTo(WidgetTester tester, double fraction) async {
  final rect = tester.getRect(find.byKey(const Key('slideToFinishBar')));
  final y = rect.center.dy;
  final gesture = await tester.startGesture(Offset(rect.left + 2, y));
  await gesture.moveTo(Offset(rect.left + rect.width * fraction, y));
  await tester.pump();
  return gesture;
}

void main() {
  testWidgets(
      'reopening with a checkpoint from before the app died shows the full elapsed time immediately',
      (tester) async {
    // Simulates exactly what a fresh CardioSessionScreen sees after a cold
    // start: movingSinceEpochMs from 12 minutes ago, never cleared because
    // the process died before it could pause. No ticker tick needed — the
    // very first frame must already show the accumulated time.
    final since = DateTime.now().subtract(const Duration(minutes: 12));
    await _pump(tester, _runningSession(movingSeconds: 60, movingSinceEpochMs: since.millisecondsSinceEpoch));

    expect(tester.takeException(), isNull);
    expect(find.text('13:00'), findsOneWidget);
  });

  testWidgets('a running session shows Pause and the slide-to-finish bar, not Resume', (tester) async {
    await _pump(tester, _runningSession(movingSinceEpochMs: DateTime.now().millisecondsSinceEpoch));

    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);
    expect(find.text('Slide to finish'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
  });

  testWidgets(
      'a paused session shows the manual pause card, Resume, and the slide-to-finish bar, not Pause',
      (tester) async {
    await _pump(tester, _pausedSession(movingSeconds: 400));

    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Slide to finish'), findsOneWidget);
    // "Paused" is the manual-pause card's title (M08) — the plain status
    // label it used to be is gone entirely while paused (C2.5).
    expect(find.text('Paused'), findsOneWidget);
  });

  testWidgets('tapping Pause sends the live moving-seconds total and freezes the display',
      (tester) async {
    final since = DateTime.now().subtract(const Duration(minutes: 2));
    final controller =
        await _pump(tester, _runningSession(movingSeconds: 60, movingSinceEpochMs: since.millisecondsSinceEpoch));

    await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
    await tester.pumpAndSettle();

    expect(controller.pauseCalls, hasLength(1));
    expect(controller.pauseCalls.single['clientId'], 'live-1');
    // 60 (base) + 120 (2 minutes) + however many ms the test took to reach
    // the tap — real wall-clock, so a tolerance rather than exact equality.
    expect(controller.pauseCalls.single['movingSeconds'], inInclusiveRange(180, 182));
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget); // manual pause card, not auto
  });

  testWidgets('tapping Resume opens a fresh checkpoint at "now"', (tester) async {
    final controller = await _pump(tester, _pausedSession(movingSeconds: 400));

    final before = DateTime.now();
    await tester.tap(find.widgetWithText(FilledButton, 'Resume'));
    await tester.pumpAndSettle();

    expect(controller.resumeCalls, hasLength(1));
    final resumedAt = controller.resumeCalls.single['resumedAt'] as DateTime;
    expect(resumedAt.difference(before).inSeconds.abs() < 2, isTrue);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Paused'), findsNothing);
  });

  testWidgets('a failed pause shows an error and leaves the session running', (tester) async {
    final controller = await _pump(
      tester,
      _runningSession(movingSinceEpochMs: DateTime.now().millisecondsSinceEpoch),
    );
    controller.failNext = true;

    await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
    await tester.pumpAndSettle();

    expect(find.text('Pause'), findsOneWidget); // still running, button unchanged
    expect(find.text('In progress'), findsOneWidget);
  });

  group('slide-to-finish (C2.5)', () {
    testWidgets('a plain tap on the slide-to-finish bar does not finish the session', (tester) async {
      final controller = await _pump(tester, _pausedSession(movingSeconds: 754));

      await tester.tap(find.byKey(const Key('slideToFinishBar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700)); // long enough to catch a stray timer

      expect(controller.finishCalls, isEmpty);
      expect(find.text('Paused'), findsOneWidget);
    });

    testWidgets(
        'dragging past the threshold shows the confirmation overlay, then finishes and stops showing controls',
        (tester) async {
      final controller = await _pump(tester, _pausedSession(movingSeconds: 754));

      final gesture = await _dragFinishBarTo(tester, 0.85);

      // Mid-drag: the M12 overlay is up, nothing sent yet.
      expect(controller.finishCalls, isEmpty);
      expect(find.text('Finish workout?'), findsOneWidget);
      expect(find.textContaining('% more'), findsOneWidget);
      expect(find.text('Release'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.finishCalls, hasLength(1));
      expect(controller.finishCalls.single['movingSeconds'], 754);
      // C2.8: finishing hands off to CardioSummaryScreen — this screen
      // shows nothing "finished" itself, it's just gone.
      expect(find.byType(CardioSummaryScreen), findsOneWidget);
      expect(find.byType(CardioSessionScreen), findsNothing);
      expect(find.byKey(const Key('slideToFinishBar')), findsNothing);
    });

    testWidgets(
        'finishing requests the Workouts screen jump back to its Sessions sub-tab '
        '(docs/cardio/59-cardio-implementation-plan.md)', (tester) async {
      await _pump(tester, _pausedSession(movingSeconds: 754));
      final container = ProviderScope.containerOf(tester.element(find.byType(CardioSessionScreen)));
      expect(container.read(workoutsSessionsTabRequestProvider), 0);

      final gesture = await _dragFinishBarTo(tester, 0.85);
      await gesture.up();
      await tester.pumpAndSettle();

      // Read via the still-mounted summary screen — CardioSessionScreen
      // itself is gone (pushReplacement), but the ProviderScope above both
      // is the same instance either way.
      final containerAfter =
          ProviderScope.containerOf(tester.element(find.byType(CardioSummaryScreen)));
      expect(containerAfter.read(workoutsSessionsTabRequestProvider), 1);
    });

    testWidgets('dragging below the threshold snaps back without finishing', (tester) async {
      final controller = await _pump(tester, _pausedSession(movingSeconds: 754));

      final gesture = await _dragFinishBarTo(tester, 0.4);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.finishCalls, isEmpty);
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Slide to finish'), findsOneWidget);
      expect(find.text('Finish workout?'), findsNothing);
    });

    testWidgets("cancelling via the overlay's Cancel row resets the drag without finishing",
        (tester) async {
      final controller = await _pump(tester, _pausedSession(movingSeconds: 754));

      final gesture = await _dragFinishBarTo(tester, 0.85);
      expect(find.text('Finish workout?'), findsOneWidget);

      await tester.tap(find.text('Cancel — back to the workout'));
      await tester.pumpAndSettle();

      expect(controller.finishCalls, isEmpty);
      expect(find.text('Finish workout?'), findsNothing);
      expect(find.text('Slide to finish'), findsOneWidget);

      // The still-down pointer has nothing left to affect — releasing it
      // now must not resurrect the overlay or finish anything.
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.finishCalls, isEmpty);
    });

    testWidgets('holding the bar for 600ms finishes the session via long-press, without dragging',
        (tester) async {
      final controller = await _pump(tester, _pausedSession(movingSeconds: 754));
      final rect = tester.getRect(find.byKey(const Key('slideToFinishBar')));

      await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();

      expect(controller.finishCalls, hasLength(1));
      expect(controller.finishCalls.single['movingSeconds'], 754);
      expect(find.byType(CardioSummaryScreen), findsOneWidget);
    });
  });

  group('auto-pause (C2.5, DISTANCE only)', () {
    testWidgets('autoPause() shows the auto-pause card, distinct from a manual pause', (tester) async {
      final controller =
          await _pump(tester, _runningSession(movingSinceEpochMs: DateTime.now().millisecondsSinceEpoch));
      final state = tester.state<CardioSessionScreenState>(find.byType(CardioSessionScreen));

      await state.autoPause();
      await tester.pumpAndSettle();

      expect(controller.pauseCalls, hasLength(1));
      expect(find.text('Automatic pause'), findsOneWidget);
      expect(find.text('Paused'), findsNothing); // not the manual card's title
      expect(find.text('Move to resume'), findsOneWidget);
      expect(find.text('Resume'), findsNothing); // not the manual resume button
    });

    testWidgets('tapping the auto-pause resume hint resumes exactly like a manual resume',
        (tester) async {
      final controller =
          await _pump(tester, _runningSession(movingSinceEpochMs: DateTime.now().millisecondsSinceEpoch));
      final state = tester.state<CardioSessionScreenState>(find.byType(CardioSessionScreen));
      await state.autoPause();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Move to resume'));
      await tester.pumpAndSettle();

      expect(controller.resumeCalls, hasLength(1));
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Automatic pause'), findsNothing);
    });

    testWidgets('autoPause() is a no-op outside the DISTANCE family', (tester) async {
      final controller =
          await _pump(tester, _runningMachineSession(movingSinceEpochMs: DateTime.now().millisecondsSinceEpoch));
      final state = tester.state<CardioSessionScreenState>(find.byType(CardioSessionScreen));

      await state.autoPause();
      await tester.pumpAndSettle();

      expect(controller.pauseCalls, isEmpty);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('Automatic pause'), findsNothing);
    });
  });

  group('Live Activity / ongoing notification bridge (C2.9)', () {
    testWidgets('starting the screen calls start() with a CARDIO state', (tester) async {
      final (_, notifier) = await _pumpWithNotifier(
        tester,
        _runningSession(movingSeconds: 1500, movingSinceEpochMs: DateTime.now().millisecondsSinceEpoch),
      );

      expect(notifier.startCalls, hasLength(1));
      final state = notifier.startCalls.single;
      expect(state.kind, 'CARDIO');
      expect(state.activityType, 'RUNNING');
      // The legacy fields an old, kind-unaware native build would still
      // read — see WorkoutSessionState.kind's doc: a real name, and no
      // sets fraction ever shows for a cardio session.
      expect(state.setsTotal, isNull);
      expect(state.exerciseName, isNotEmpty);
      expect(state.cardio, isNotNull);
      expect(state.cardio!.paused, isFalse);
    });

    testWidgets('pausing pushes an update() with paused: true', (tester) async {
      final (_, notifier) = await _pumpWithNotifier(
        tester,
        _runningSession(movingSinceEpochMs: DateTime.now().millisecondsSinceEpoch),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
      await tester.pumpAndSettle();

      expect(notifier.updateCalls, isNotEmpty);
      expect(notifier.updateCalls.last.cardio!.paused, isTrue);
    });

    testWidgets('resuming pushes an update() with paused: false', (tester) async {
      final (_, notifier) = await _pumpWithNotifier(tester, _pausedSession(movingSeconds: 400));

      await tester.tap(find.widgetWithText(FilledButton, 'Resume'));
      await tester.pumpAndSettle();

      expect(notifier.updateCalls, isNotEmpty);
      expect(notifier.updateCalls.last.cardio!.paused, isFalse);
    });

    testWidgets('editing the live distance pushes an update() reflecting the new value',
        (tester) async {
      final (_, notifier) = await _pumpWithNotifier(tester, _pausedSession(movingSeconds: 400));
      notifier.updateCalls.clear();

      await tester.tap(find.text('DISTANCE'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '5');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(notifier.updateCalls, isNotEmpty);
      expect(notifier.updateCalls.last.cardio!.primaryValue, contains('5'));
    });

    testWidgets('finishing calls end()', (tester) async {
      final (_, notifier) = await _pumpWithNotifier(tester, _pausedSession(movingSeconds: 754));

      final gesture = await _dragFinishBarTo(tester, 0.85);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(notifier.endCalls, 1);
    });
  });

  group('watch bridge (C5.2, docs/cardio/55-cardio-watch-plan.md §5/W-2)', () {
    testWidgets('starting the screen calls startWorkout() with activityType, and venue when set',
        (tester) async {
      final (_, watch) = await _pumpWithWatch(
        tester,
        WorkoutSession(
          clientId: 'live-1',
          exercises: const [],
          sets: const [],
          startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
          sessionKind: 'CARDIO',
          activityType: 'RUNNING',
          movingSeconds: 0,
          movingSinceEpochMs: DateTime.now().millisecondsSinceEpoch,
          cardio: const CardioMetrics(venue: 'OUTDOOR'),
        ),
      );

      expect(watch.startCalls, hasLength(1));
      final call = watch.startCalls.single;
      expect(call.sessionClientId, 'live-1');
      expect(call.activityType, 'RUNNING');
      expect(call.venue, 'OUTDOOR');
      expect(call.state.kind, 'CARDIO');
    });

    testWidgets('venue is null when the session never set one (DISTANCE has no venue concept)',
        (tester) async {
      final (_, watch) = await _pumpWithWatch(
        tester,
        _runningSession(movingSinceEpochMs: DateTime.now().millisecondsSinceEpoch),
      );

      expect(watch.startCalls.single.venue, isNull);
    });

    testWidgets('pausing pushes an updateState() call', (tester) async {
      final (_, watch) = await _pumpWithWatch(
        tester,
        _runningSession(movingSinceEpochMs: DateTime.now().millisecondsSinceEpoch),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
      await tester.pumpAndSettle();

      expect(watch.updateCalls, isNotEmpty);
      expect(watch.updateCalls.last.cardio!.paused, isTrue);
    });

    testWidgets('finishing calls endWorkout() exactly once', (tester) async {
      final (_, watch) = await _pumpWithWatch(tester, _pausedSession(movingSeconds: 754));

      final gesture = await _dragFinishBarTo(tester, 0.85);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(watch.endCalls, 1);
    });

    testWidgets('watchWorkoutEnabled: false suppresses updateState pushes', (tester) async {
      // `_watchEnabled` reads the settings stream's already-resolved value
      // (same `?? true` fallback as `LogSessionScreen._watchEnabled`) — the
      // very first push, from `initState`'s deferred `_startSessionNotifier`,
      // can race ahead of that stream's first emission and default to
      // enabled, exactly like `LogSessionScreen`'s already does. That race
      // isn't this test's concern; `_updateSessionNotifier` re-checks the
      // flag on every later call once settings have long since settled,
      // which is what a pause reliably exercises.
      final controller = _RecordingSessionController();
      final watch = _RecordingWatchService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            workoutSessionControllerProvider.overrideWith(() => controller),
            settingsControllerProvider.overrideWith(
              () => _DisabledWatchSettings(),
            ),
            watchWorkoutServiceProvider.overrideWithValue(watch),
            locationServiceProvider.overrideWithValue(_grantedLocationStub()),
            appDatabaseProvider.overrideWithValue(_testDatabase()),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CardioSessionScreen(
              session: _runningSession(movingSinceEpochMs: DateTime.now().millisecondsSinceEpoch),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      watch.updateCalls.clear();

      await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
      await tester.pumpAndSettle();

      expect(watch.updateCalls, isEmpty);
    });
  });
}

class _DisabledWatchSettings extends SettingsController {
  @override
  Stream<UserSettings> build() =>
      Stream.value(const UserSettings.defaults().copyWith(watchWorkoutEnabled: false));
}
