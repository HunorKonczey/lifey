import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/location/location_service.dart';
import 'package:lifey/core/location/location_service_geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/watch/watch_workout_service.dart';
import 'package:lifey/core/workout_session_notifier/workout_session_notifier_service.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_session_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// C2.4: the GAME family layout on `CardioSessionScreen` — the two
/// independent clocks (playing time vs. gross time) and the on-court/bench
/// toggle. docs/cardio/59-cardio-implementation-plan.md C2.4 — kész-ha:
/// "A játékidő és a bruttó idő külön viselkedik (teszt)."
///
/// Numeric ticking can't be exercised here without a fake clock (both
/// `_liveMovingSeconds` and `_liveGrossSeconds` read real `DateTime.now()`,
/// which `tester.pump(duration)` doesn't advance) — so "the two clocks
/// differ" is proven the same way C2.1's kill-recovery test proved exact
/// restoration: by constructing a session whose persisted fields already
/// encode two different frozen values, and reading them off the very first
/// frame. The toggle/pause *control flow* (what gets frozen, what doesn't,
/// what's disabled when) is proven directly via the recorded controller
/// calls instead.

class _RecordingSessionController extends WorkoutSessionController {
  final pauseCalls = <Map<String, Object?>>[];
  final resumeCalls = <Map<String, Object?>>[];

  /// C9.2 — every box-score tap lands here, as the merged `CardioMetrics` the
  /// screen reconstructs.
  final liveMetricCalls = <Map<String, Object?>>[];

  @override
  Future<void> updateLiveCardioMetrics(String clientId,
      {required DateTime startedAt, required CardioMetrics cardio}) async {
    liveMetricCalls.add({'cardio': cardio});
  }

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);

  @override
  Future<void> pauseCardioSession(String clientId,
      {required DateTime startedAt, required int movingSeconds}) async {
    pauseCalls.add({'movingSeconds': movingSeconds});
  }

  @override
  Future<void> resumeCardioSession(String clientId,
      {required DateTime startedAt, required DateTime resumedAt}) async {
    resumeCalls.add({'resumedAt': resumedAt});
  }

  final finishCalls = <Map<String, Object?>>[];

  @override
  Future<void> finishCardioSession(String clientId,
      {required DateTime startedAt,
      required DateTime finishedAt,
      required int movingSeconds,
      Value<CardioMetrics?> cardio = const Value.absent(),
      Value<List<CardioSplit>> splits = const Value.absent()}) async {
    finishCalls.add({
      'cardio': cardio.present ? cardio.value : null,
      'splits': splits.present ? splits.value : null,
    });
  }
}


/// Counts what a session actually asks of the location service — the only way
/// to prove C9.4's battery guarantee: an indoor match must not subscribe to
/// availability *or* to positions, so no permission prompt and no radio.
class _CountingLocationStub extends LocationServiceStub {
  _CountingLocationStub()
      : super(
          initial: const LocationAvailability(
            authorization: LocationAuthorization.granted,
            precise: true,
            serviceEnabled: true,
          ),
        );

  int availabilityListens = 0;
  int positionStreamCalls = 0;

  @override
  Stream<LocationAvailability> get availability {
    availabilityListens++;
    return super.availability;
  }

  @override
  Stream<LocationFix> positionStream({
    required LocationTrackingProfile profile,
    String androidNotificationTitle = 'Lifey',
    String androidNotificationText = 'Recording your route',
  }) {
    positionStreamCalls++;
    return super.positionStream(
      profile: profile,
      androidNotificationTitle: androidNotificationTitle,
      androidNotificationText: androidNotificationText,
    );
  }
}

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

WorkoutSession _liveOnCourtSession({int movingSeconds = 0, Duration since = Duration.zero}) {
  final startedAt = DateTime.now().subtract(since);
  return WorkoutSession(
    clientId: 'live-1',
    exercises: const [],
    sets: const [],
    startedAt: startedAt,
    sessionKind: 'CARDIO',
    activityType: 'BASKETBALL',
    movingSeconds: movingSeconds,
    movingSinceEpochMs: startedAt.millisecondsSinceEpoch,
  );
}

/// A session frozen (no `movingSinceEpochMs`) with distinct, code-controlled
/// `movingSeconds` and elapsed-since-`startedAt` values, so the dominant
/// (playing time) and gross-time tiles read two different numbers on the
/// very first frame without needing any ticking.
WorkoutSession _reloadedFrozenSession() {
  final startedAt = DateTime.now().subtract(const Duration(minutes: 20));
  return WorkoutSession(
    clientId: 'live-1',
    exercises: const [],
    sets: const [],
    startedAt: startedAt,
    sessionKind: 'CARDIO',
    activityType: 'BASKETBALL',
    movingSeconds: 600, // 10:00 playing time, frozen
    // movingSinceEpochMs absent -> "frozen", ambiguous manual-pause/bench.
  );
}


AppDatabase _testDatabase() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// The W-9 counterpart of [_RecordingSessionController]: drives watch events
/// *into* the screen (the wrist's own pályán/padon tap) and records the state
/// pushed back out, without touching the real MethodChannel.
class _FakeWatchService extends WatchWorkoutService {
  _FakeWatchService() : super(isAvailable: false);

  final _events = StreamController<Object>.broadcast();
  final updateCalls = <WorkoutSessionState>[];

  @override
  Stream<Object> get events => _events.stream;

  @override
  Future<void> startWorkout({
    required String sessionClientId,
    required String title,
    required DateTime startedAt,
    required WorkoutSessionState state,
    String? activityType,
    String? venue,
  }) async {}

  @override
  Future<void> updateState({
    required String sessionClientId,
    required WorkoutSessionState state,
  }) async {
    updateCalls.add(state);
  }

  void emit(Object event) => _events.add(event);

  void dispose() => _events.close();
}

Future<_RecordingSessionController> _pump(
  WidgetTester tester,
  WorkoutSession session, {
  _CountingLocationStub? location,
  _FakeWatchService? watch,
}) async {
  // Taller than the default 800x600: since C9.2 the GAME body can carry the
  // offer card or the stepper panel *and* the tray below it, and a control
  // scrolled out of view can't be tapped.
  await tester.binding.setSurfaceSize(const Size(400, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = _RecordingSessionController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => controller),
        settingsControllerProvider.overrideWith(_MetricSettings.new),
        if (location != null) locationServiceProvider.overrideWithValue(location),
        if (location != null) appDatabaseProvider.overrideWithValue(_testDatabase()),
        if (watch != null) watchWorkoutServiceProvider.overrideWithValue(watch),
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

void main() {
  // C9.2 reads BoxScorePreferences from initState for every GAME session, so
  // every test in this file needs the plugin stubbed. Declined by default:
  // most of these cases are about the clocks, not the box score, and the
  // offer card would otherwise sit in the middle of them.
  setUp(() => SharedPreferences.setMockInitialValues({'cardio.boxScoreOffer': 'declined'}));

  testWidgets('shows playing time as dominant, and gross/heart-rate/zone as secondary',
      (tester) async {
    await _pump(tester, _liveOnCourtSession());

    expect(tester.takeException(), isNull);
    expect(find.text('PLAYING TIME — ON COURT'), findsOneWidget);
    expect(find.text('GROSS TIME'), findsOneWidget);
    expect(find.text('HEART RATE'), findsOneWidget);
    expect(find.text('ZONE'), findsOneWidget);
    expect(find.text('On court'), findsOneWidget);
    expect(find.text('Bench'), findsOneWidget);
  });

  testWidgets('the box score is hidden behind its own button, never always-on (C9.2, Q-D2)',
      (tester) async {
    // This test used to assert that no counter existed at all, because Q-D2
    // was open. C9.2 resolved it: the counter exists, but it is *hidden by
    // default* — in a pocket or while defending, an always-open stepper
    // collects accidental taps.
    SharedPreferences.setMockInitialValues({'cardio.boxScoreOffer': 'declined'});
    await _pump(tester, _liveOnCourtSession());
    await tester.pump();

    expect(find.byKey(const Key('boxScoreCircle')), findsOneWidget);
    expect(find.text('POINTS'), findsNothing);
    expect(find.text('closes after 6 s'), findsNothing);
  });

  testWidgets('a reloaded frozen session shows two different frozen numbers immediately',
      (tester) async {
    await _pump(tester, _reloadedFrozenSession());

    // Playing time: exactly the persisted 600s, frozen — deterministic.
    expect(find.text('10:00'), findsOneWidget);
    // Gross time: the "assume it's been running since start" fallback,
    // ~20 minutes — not exact (real wall-clock elapsed during the test run
    // adds a little), so a tolerant textContaining check on the minutes.
    expect(find.textContaining('20:0'), findsOneWidget);
    // Ambiguous reload defaults to "manually paused" — Resume, not Pause.
    expect(find.text('Resume'), findsOneWidget);
  });

  testWidgets('tapping Bench freezes playing time via pauseCardioSession', (tester) async {
    final controller = await _pump(tester, _liveOnCourtSession(movingSeconds: 60));

    await tester.tap(find.text('Bench'));
    await tester.pumpAndSettle();

    expect(controller.pauseCalls, hasLength(1));
    expect(controller.pauseCalls.single['movingSeconds'], greaterThanOrEqualTo(60));
  });

  testWidgets('tapping On court after Bench resumes playing time via resumeCardioSession',
      (tester) async {
    final controller = await _pump(tester, _liveOnCourtSession(movingSeconds: 60));

    await tester.tap(find.text('Bench'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('On court'));
    await tester.pumpAndSettle();

    expect(controller.resumeCalls, hasLength(1));
  });

  testWidgets('the watch\'s own Bench tap freezes playing time here too (W-9)', (tester) async {
    // The wrist and the phone show the same switch, so a tap on either has to
    // land in the same place: `_setOnCourt`, freezing playing time while
    // gross time keeps running.
    final watch = _FakeWatchService();
    addTearDown(watch.dispose);
    final controller = await _pump(tester, _liveOnCourtSession(movingSeconds: 60), watch: watch);

    watch.emit(const WatchCourtChanged(sessionClientId: 'live-1', onCourt: false));
    await tester.pumpAndSettle();

    expect(controller.pauseCalls, hasLength(1));
    expect(find.text('On court'), findsOneWidget);
    // …and the new state goes straight back out to the watch, so the two
    // screens agree without a second round trip.
    expect(watch.updateCalls.last.cardio?.onCourt, isFalse);
  });

  testWidgets('a court change for a different session is ignored', (tester) async {
    final watch = _FakeWatchService();
    addTearDown(watch.dispose);
    final controller = await _pump(tester, _liveOnCourtSession(movingSeconds: 60), watch: watch);

    watch.emit(const WatchCourtChanged(sessionClientId: 'someone-else', onCourt: false));
    await tester.pumpAndSettle();

    expect(controller.pauseCalls, isEmpty);
  });

  testWidgets('the state pushed to the watch carries the court/bench flag', (tester) async {
    final watch = _FakeWatchService();
    addTearDown(watch.dispose);
    await _pump(tester, _liveOnCourtSession(movingSeconds: 60), watch: watch);

    await tester.tap(find.text('Bench'));
    await tester.pumpAndSettle();

    expect(watch.updateCalls, isNotEmpty);
    expect(watch.updateCalls.last.cardio?.onCourt, isFalse);
  });

  testWidgets('Meccs szünet (Pause) disables both toggle buttons', (tester) async {
    await _pump(tester, _liveOnCourtSession(movingSeconds: 60));

    await tester.tap(find.text('Match pause'));
    await tester.pumpAndSettle();

    final onCourtButton = tester.widget<InkWell>(
      find.ancestor(of: find.text('On court'), matching: find.byType(InkWell)),
    );
    final benchButton = tester.widget<InkWell>(
      find.ancestor(of: find.text('Bench'), matching: find.byType(InkWell)),
    );
    expect(onCourtButton.onTap, isNull);
    expect(benchButton.onTap, isNull);
  });

  testWidgets('resuming from Meccs szünet while still on court resumes playing time',
      (tester) async {
    final controller = await _pump(tester, _liveOnCourtSession(movingSeconds: 60));

    await tester.tap(find.text('Match pause'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    // One resume from pausing, one more from resuming = two total; the
    // moving-specific one is what we care about here — both count as
    // "resumeCardioSession got called", which is what matters: playing
    // time picks back up automatically since the player never benched.
    expect(controller.resumeCalls, hasLength(1));
    expect(find.text('Match pause'), findsOneWidget); // back to the running state
  });

  testWidgets('resuming from Meccs szünet while benched does NOT resume playing time',
      (tester) async {
    final controller = await _pump(tester, _liveOnCourtSession(movingSeconds: 60));

    await tester.tap(find.text('Bench')); // benches first
    await tester.pumpAndSettle();
    await tester.tap(find.text('Match pause')); // then a whole-session pause
    await tester.pumpAndSettle();
    controller.resumeCalls.clear(); // drop the (absent) bench-related noise, isolate what follows

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    // Manual resume alone must not restart movingSeconds — the player is
    // still on the bench.
    expect(controller.resumeCalls, isEmpty);
  });

  // -- Box score (C9.2, M44) -----------------------------------------------

  group('box score', () {
    testWidgets('the Box circle opens the stepper, and taps count', (tester) async {
      final controller = await _pump(tester, _liveOnCourtSession(movingSeconds: 60));
      await tester.pump();

      await tester.tap(find.byKey(const Key('boxScoreCircle')));
      await tester.pumpAndSettle();

      expect(find.text('POINTS'), findsOneWidget);
      expect(find.text('REBOUNDS'), findsOneWidget);
      expect(find.text('ASSISTS'), findsOneWidget);
      expect(find.text('closes after 6 s'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      final cardio = controller.liveMetricCalls.last['cardio'] as CardioMetrics;
      expect(cardio.scorePoints, 1);
    });

    testWidgets('counting a basket never touches the clock', (tester) async {
      // The kesz-ha: the stepper does not reach movingSeconds. Only the
      // court/bench switch moves playing time.
      final controller = await _pump(tester, _liveOnCourtSession(movingSeconds: 60));
      await tester.pump();
      await tester.tap(find.byKey(const Key('boxScoreCircle')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      expect(controller.pauseCalls, isEmpty);
      expect(controller.resumeCalls, isEmpty);
    });

    testWidgets('the panel closes itself after 6 s of no interaction', (tester) async {
      await _pump(tester, _liveOnCourtSession());
      await tester.pump();
      await tester.tap(find.byKey(const Key('boxScoreCircle')));
      await tester.pumpAndSettle();
      expect(find.text('POINTS'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(find.text('POINTS'), findsNothing);
    });

    testWidgets('a tap restarts the idle countdown rather than the panel racing it',
        (tester) async {
      await _pump(tester, _liveOnCourtSession());
      await tester.pump();
      await tester.tap(find.byKey(const Key('boxScoreCircle')));
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 4));
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4)); // 8 s since opening

      expect(find.text('POINTS'), findsOneWidget, reason: 'idle time, not time-since-open');
    });

    testWidgets('the plus target is 1.4x wider than the minus', (tester) async {
      await _pump(tester, _liveOnCourtSession());
      await tester.pump();
      await tester.tap(find.byKey(const Key('boxScoreCircle')));
      await tester.pumpAndSettle();

      final plus = tester.getSize(find.ancestor(
        of: find.byIcon(Icons.add).first,
        matching: find.byType(SizedBox),
      ).first);
      final minus = tester.getSize(find.ancestor(
        of: find.byIcon(Icons.remove).first,
        matching: find.byType(SizedBox),
      ).first);

      expect(plus.width / minus.width, closeTo(1.4, 0.01));
      expect(plus.height, 44);
    });

    testWidgets('the court switch keeps its size and place when the panel opens',
        (tester) async {
      await _pump(tester, _liveOnCourtSession());
      await tester.pump();
      final before = tester.getRect(find.text('On court'));

      await tester.tap(find.byKey(const Key('boxScoreCircle')));
      await tester.pumpAndSettle();

      expect(tester.getRect(find.text('On court')), before);
    });

    testWidgets('football gets two columns - a rebound is not a concept there',
        (tester) async {
      await _pump(
        tester,
        WorkoutSession(
          clientId: 'live-1',
          exercises: const [],
          sets: const [],
          startedAt: DateTime.now(),
          sessionKind: 'CARDIO',
          activityType: 'FOOTBALL',
          movingSeconds: 0,
          movingSinceEpochMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('boxScoreCircle')));
      await tester.pumpAndSettle();

      expect(find.text('GOALS'), findsOneWidget);
      expect(find.text('ASSISTS'), findsOneWidget);
      expect(find.text('REBOUNDS'), findsNothing);
      expect(find.text('POINTS'), findsNothing);
    });

    testWidgets('minus cannot go below zero', (tester) async {
      final controller = await _pump(tester, _liveOnCourtSession());
      await tester.pump();
      await tester.tap(find.byKey(const Key('boxScoreCircle')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove).first);
      await tester.pumpAndSettle();

      expect(controller.liveMetricCalls, isEmpty);
    });
  });

  group('the one-time offer (Q-D2)', () {
    testWidgets('an unanswered offer is shown once, and accepting opens the stepper',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester, _liveOnCourtSession());
      await tester.pump();

      expect(find.text('Keep score?'), findsOneWidget);

      await tester.tap(find.text('Yes, please'));
      await tester.pumpAndSettle();

      expect(find.text('Keep score?'), findsNothing);
      expect(find.text('POINTS'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cardio.boxScoreOffer'), 'accepted');
    });

    testWidgets('declining is remembered forever - the question never returns',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pump(tester, _liveOnCourtSession());
      await tester.pump();

      await tester.tap(find.text('No thanks'));
      await tester.pumpAndSettle();

      expect(find.text('Keep score?'), findsNothing);
      expect(find.text('POINTS'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cardio.boxScoreOffer'), 'declined');
    });

    testWidgets('an already-declined session is never asked again', (tester) async {
      SharedPreferences.setMockInitialValues({'cardio.boxScoreOffer': 'declined'});
      await _pump(tester, _liveOnCourtSession());
      await tester.pump();

      expect(find.text('Keep score?'), findsNothing);
      // Still reachable for someone who changes their mind - M44's hidden
      // default state is "only the Box circle shows".
      expect(find.byKey(const Key('boxScoreCircle')), findsOneWidget);
    });

    testWidgets('an accepted answer opens the stepper on the next match without asking',
        (tester) async {
      SharedPreferences.setMockInitialValues({'cardio.boxScoreOffer': 'accepted'});
      await _pump(tester, _liveOnCourtSession());
      await tester.pump();

      expect(find.text('Keep score?'), findsNothing);
      expect(find.text('POINTS'), findsOneWidget);
    });
  });

  testWidgets('counting a basket preserves the venue and intensity (C9.2)', (tester) async {
    // `updateLiveCardioMetrics` full-replaces the cardio row. Before C9.2
    // nothing on a GAME session could reach that write, so the omission of
    // venue/intensity was latent — the box-score stepper is its first GAME
    // caller, and without carrying them a single tap would wipe both.
    final started = DateTime.now();
    final controller = await _pump(
      tester,
      WorkoutSession(
        clientId: 'live-1',
        exercises: const [],
        sets: const [],
        startedAt: started,
        sessionKind: 'CARDIO',
        activityType: 'BASKETBALL',
        movingSeconds: 60,
        movingSinceEpochMs: started.millisecondsSinceEpoch,
        cardio: const CardioMetrics(venue: 'INDOOR', intensity: 4),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('boxScoreCircle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    final cardio = controller.liveMetricCalls.single['cardio'] as CardioMetrics;
    expect(cardio.scorePoints, 1);
    expect(cardio.venue, 'INDOOR');
    expect(cardio.intensity, 4);
  });

  testWidgets('two quick taps in one frame both count', (tester) async {
    // The stepper reports a step, not a finished number: two taps landing
    // before a rebuild would otherwise each compute "the value I was built
    // with, plus one", and a basket would go missing.
    final controller = await _pump(tester, _liveOnCourtSession(movingSeconds: 60));
    await tester.pump();
    await tester.tap(find.byKey(const Key('boxScoreCircle')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(
      (controller.liveMetricCalls.last['cardio'] as CardioMetrics).scorePoints,
      2,
    );
  });

  group('outdoor GPS (C9.4)', () {
    WorkoutSession match({required String venue}) {
      final started = DateTime.now();
      return WorkoutSession(
        clientId: 'live-1',
        exercises: const [],
        sets: const [],
        startedAt: started,
        sessionKind: 'CARDIO',
        activityType: 'BASKETBALL',
        movingSeconds: 0,
        movingSinceEpochMs: started.millisecondsSinceEpoch,
        cardio: CardioMetrics(venue: venue, gameFormat: '5V5'),
      );
    }

    testWidgets('an indoor match never touches the location service', (tester) async {
      // The battery guarantee: no availability subscription (so no permission
      // prompt) and no position stream (so no radio). "Nem letiltva, hanem nem
      // létezik."
      SharedPreferences.setMockInitialValues({
        'cardio.boxScoreOffer': 'declined',
        'cardio.gameGps': true, // even with the opt-in left on from outdoors
      });
      final location = _CountingLocationStub();
      await _pump(tester, match(venue: 'INDOOR'), location: location);
      await tester.pump();
      await tester.pump();

      expect(location.availabilityListens, 0);
      expect(location.positionStreamCalls, 0);
    });

    testWidgets('an outdoor match without the opt-in also stays off', (tester) async {
      SharedPreferences.setMockInitialValues({
        'cardio.boxScoreOffer': 'declined',
        'cardio.gameGps': false,
      });
      final location = _CountingLocationStub();
      await _pump(tester, match(venue: 'OUTDOOR'), location: location);
      await tester.pump();
      await tester.pump();

      expect(location.availabilityListens, 0);
      expect(location.positionStreamCalls, 0);
    });

    testWidgets('an outdoor match with the opt-in records distance', (tester) async {
      SharedPreferences.setMockInitialValues({
        'cardio.boxScoreOffer': 'declined',
        'cardio.gameGps': true,
      });
      final location = _CountingLocationStub();
      final controller = await _pump(tester, match(venue: 'OUTDOOR'), location: location);
      await tester.pump();
      await tester.pump();

      expect(location.availabilityListens, greaterThan(0));
      expect(location.positionStreamCalls, greaterThan(0));

      // ~11 m apart, 3 s apart — the same fixture shape the GPS tests use.
      // The live GAME screen has no distance tile (M07/M43 don't draw one), so
      // the recording is read off the closing write, where it actually lands.
      for (var n = 0; n < 6; n++) {
        location.emitFix(LocationFix(
          latitude: 47.5 + n * 0.0001,
          longitude: 19.05,
          speed: 4,
          recordedAt: DateTime.utc(2026, 8, 17, 19).add(Duration(seconds: n * 3)),
        ));
        await tester.pump();
      }

      final rect = tester.getRect(find.byKey(const Key('slideToFinishBar')));
      await tester.startGesture(rect.center);
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();

      final call = controller.finishCalls.single;
      final cardio = call['cardio'] as CardioMetrics?;
      expect(cardio?.distanceMeters, greaterThan(0));
      expect(cardio?.routePolyline, isNotNull);
      expect(cardio?.distanceSource, 'MEASURED');
      // The match keeps its own fields through the closing write.
      expect(cardio?.venue, 'OUTDOOR');
      expect(cardio?.gameFormat, '5V5');
      // And gets nothing derived from pace: no km splits, no best efforts.
      expect(call['splits'], isEmpty);
      expect(cardio?.best1kSeconds, isNull);
      expect(cardio?.best5kSeconds, isNull);
    });
  });
}
