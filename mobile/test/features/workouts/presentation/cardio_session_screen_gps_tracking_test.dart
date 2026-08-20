import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/location/location_service.dart';
import 'package:lifey/core/location/location_service_geolocator.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/data/cardio_track_point_repository.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_session_screen.dart';
import 'package:lifey/features/workouts/presentation/cardio_summary_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// C4a.4 — live GPS distance/weak-signal UI wired into `CardioSessionScreen`
/// (M04 healthy, M10 weak). docs/cardio/59-cardio-implementation-plan.md
/// C4a.4 — kész-ha (UI half): the header chip, the weak-signal banner, the
/// dominant-metric "ESTIMATED" badge, and the pace tile all react to
/// `TrackFilterAccumulator` state exactly as M04/M10 spec, and GPS becomes
/// (and stays) the authoritative distance source once it contributes
/// anything. `track_filter_test.dart` covers the accumulator itself; this
/// file is purely about the screen's reaction to it.

class _RecordingSessionController extends WorkoutSessionController {
  final finishCalls = <Map<String, Object?>>[];

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);

  @override
  Future<void> pauseCardioSession(String clientId,
      {required DateTime startedAt, required int movingSeconds}) async {}

  @override
  Future<void> resumeCardioSession(String clientId,
      {required DateTime startedAt, required DateTime resumedAt}) async {}

  @override
  Future<void> finishCardioSession(String clientId,
      {required DateTime startedAt,
      required DateTime finishedAt,
      required int movingSeconds,
      Value<CardioMetrics?> cardio = const Value.absent(),
      Value<List<CardioSplit>> splits = const Value.absent()}) async {
    finishCalls.add({
      'clientId': clientId,
      'movingSeconds': movingSeconds,
      'cardio': cardio.present ? cardio.value : null,
      'splits': splits.present ? splits.value : null,
    });
  }

  @override
  Future<void> updateLiveCardioMetrics(String clientId,
      {required DateTime startedAt, required CardioMetrics cardio}) async {}
}

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

WorkoutSession _runningSession({String clientId = 'live-1', String activityType = 'RUNNING'}) {
  final since = DateTime.now().subtract(const Duration(minutes: 5));
  return WorkoutSession(
    clientId: clientId,
    exercises: const [],
    sets: const [],
    startedAt: since,
    sessionKind: 'CARDIO',
    activityType: activityType,
    movingSeconds: 0,
    movingSinceEpochMs: since.millisecondsSinceEpoch,
  );
}

LocationServiceStub _grantedLocationStub() => LocationServiceStub(
      initial: const LocationAvailability(
        authorization: LocationAuthorization.granted,
        precise: true,
        serviceEnabled: true,
      ),
    );

/// A fixed epoch, not `DateTime.now()`: in a `testWidgets` fake-async zone,
/// two `DateTime.now()` calls separated only by a zero-duration `pump()`
/// (rather than a real delay) can land on the exact same instant, which
/// would make the speed gate's elapsed-time divisor zero and silently
/// reject every fix (see `TrackFilterAccumulator.addFix`'s non-positive-gap
/// branch). Deterministic offsets sidestep that entirely.
final _epoch = DateTime.utc(2026, 8, 13, 7, 0, 0);

/// A fix ~11 m north of the previous one (well over the 3 m displacement
/// gate), 3 s apart (~13.3 km/h — plausible for a run, well under RUNNING's
/// 30 km/h speed-gate ceiling).
LocationFix _fixAt(int n, {double? altitude}) => LocationFix(
      latitude: 47.5 + n * 0.0001,
      longitude: 19.05,
      altitude: altitude,
      recordedAt: _epoch.add(Duration(seconds: n * 3)),
    );

AppDatabase _testDatabase() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// The screen's own weak-signal countdown (`_weakSignalThreshold`) — kept in
/// sync with the source's private constant by simply picking a duration long
/// enough to always exceed it, since the field itself isn't exported. Any
/// value at or above the real threshold behaves identically for these tests.
const _pastWeakSignalThreshold = Duration(seconds: 16);

Future<
    ({
      _RecordingSessionController controller,
      LocationServiceStub location,
      AppDatabase db,
    })> _pump(
  WidgetTester tester, {
  WorkoutSession? session,
  LocationServiceStub? location,
}) async {
  final controller = _RecordingSessionController();
  final loc = location ?? _grantedLocationStub();
  final db = _testDatabase();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => controller),
        settingsControllerProvider.overrideWith(_MetricSettings.new),
        locationServiceProvider.overrideWithValue(loc),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CardioSessionScreen(session: session ?? _runningSession()),
      ),
    ),
  );
  await tester.pump();
  return (controller: controller, location: loc, db: db);
}

void main() {
  testWidgets('a healthy accepted fix shows the GPS chip, no ESTIMATED badge, live distance',
      (tester) async {
    final ctx = await _pump(tester);

    ctx.location.emitFix(_fixAt(0));
    await tester.pump();
    ctx.location.emitFix(_fixAt(1));
    await tester.pump();

    expect(find.text('GPS'), findsOneWidget);
    expect(find.text('Weak GPS'), findsNothing);
    expect(find.text('ESTIMATED'), findsNothing);
    expect(find.textContaining('km'), findsWidgets); // dominant distance now shown
  });

  testWidgets('no fix for the weak-signal threshold: chip flips to weak, banner shows, '
      'distance gets ESTIMATED, pace blanks to no signal', (tester) async {
    final ctx = await _pump(tester);
    ctx.location.emitFix(_fixAt(0));
    await tester.pump();
    ctx.location.emitFix(_fixAt(1)); // establishes a nonzero distance first
    await tester.pump();
    expect(find.text('GPS'), findsOneWidget);

    await tester.pump(_pastWeakSignalThreshold);

    expect(find.text('Weak GPS'), findsOneWidget);
    expect(find.text('GPS'), findsNothing);
    expect(find.textContaining('Signal is weak'), findsOneWidget);
    expect(find.text('ESTIMATED'), findsOneWidget);
    expect(find.text('—:—'), findsOneWidget);
    expect(find.text('no signal'), findsOneWidget);
    expect(find.text('PACE'), findsNothing); // replaced, not just supplemented
  });

  testWidgets('a fresh fix after going weak clears it back to healthy immediately',
      (tester) async {
    final ctx = await _pump(tester);
    ctx.location.emitFix(_fixAt(0));
    await tester.pump();
    ctx.location.emitFix(_fixAt(1));
    await tester.pump();
    await tester.pump(_pastWeakSignalThreshold);
    expect(find.text('Weak GPS'), findsOneWidget);

    ctx.location.emitFix(_fixAt(2));
    await tester.pump();

    expect(find.text('GPS'), findsOneWidget);
    expect(find.text('Weak GPS'), findsNothing);
    expect(find.text('ESTIMATED'), findsNothing);
    expect(find.text('PACE'), findsOneWidget);
  });

  testWidgets('pausing clears the chip entirely — canTrack stays true, but nothing is expected',
      (tester) async {
    final ctx = await _pump(tester);
    ctx.location.emitFix(_fixAt(0));
    await tester.pump();
    ctx.location.emitFix(_fixAt(1));
    await tester.pump();
    expect(find.text('GPS'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();

    expect(find.text('GPS'), findsNothing);
    expect(find.text('Weak GPS'), findsNothing);
    expect(find.text('No GPS'), findsNothing);

    // And it doesn't retroactively decide it was "weak" while paused either.
    await tester.pump(_pastWeakSignalThreshold);
    expect(find.text('Weak GPS'), findsNothing);
  });

  testWidgets('once GPS has produced distance, tapping the dominant number no longer opens '
      'the manual-edit dialog', (tester) async {
    final ctx = await _pump(tester);
    ctx.location.emitFix(_fixAt(0));
    await tester.pump();
    ctx.location.emitFix(_fixAt(1));
    await tester.pump();

    // The dominant metric specifically — `find.textContaining('km')` would
    // also match the pace tile's "… /km" suffix.
    await tester.tap(find.text('0.01 km'));
    await tester.pumpAndSettle();

    expect(find.text('Update distance'), findsNothing);
  });

  testWidgets('finishing a GPS-tracked session persists distanceSource MEASURED, not MANUAL',
      (tester) async {
    final ctx = await _pump(tester);
    ctx.location.emitFix(_fixAt(0));
    await tester.pump();
    ctx.location.emitFix(_fixAt(1));
    await tester.pump();

    final rect = tester.getRect(find.byKey(const Key('slideToFinishBar')));
    await tester.startGesture(rect.center);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();

    expect(ctx.controller.finishCalls, hasLength(1));
    final summary = tester.widget<CardioSummaryScreen>(find.byType(CardioSummaryScreen));
    expect(summary.session.cardio?.distanceSource, 'MEASURED');
    expect(summary.session.cardio?.distanceMeters, greaterThan(0));
  });

  testWidgets('finishing a GPS-tracked session persists a route polyline and splits (C4a.6)',
      (tester) async {
    final ctx = await _pump(tester);
    ctx.location.emitFix(_fixAt(0));
    await tester.pump();
    ctx.location.emitFix(_fixAt(1));
    await tester.pump();
    ctx.location.emitFix(_fixAt(2));
    await tester.pump();

    final rect = tester.getRect(find.byKey(const Key('slideToFinishBar')));
    await tester.startGesture(rect.center);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();

    // The outbox write itself carried the route, not just the throwaway
    // display object handed to CardioSummaryScreen.
    final call = ctx.controller.finishCalls.single;
    final persistedCardio = call['cardio'] as CardioMetrics?;
    expect(persistedCardio?.routePolyline, isNotNull);
    expect(persistedCardio!.routePolyline, isNotEmpty);
    expect(persistedCardio.routePointCount, greaterThan(0));
    final persistedSplits = call['splits'] as List<CardioSplit>?;
    expect(persistedSplits, isNotNull);
    expect(persistedSplits, isNotEmpty);

    final summary = tester.widget<CardioSummaryScreen>(find.byType(CardioSummaryScreen));
    expect(summary.session.cardio?.routePolyline, persistedCardio.routePolyline);
    expect(summary.session.splits, isNotEmpty);
  });

  testWidgets('finishing a run over a km persists the best 1 km alongside the splits (C6.3)',
      (tester) async {
    final ctx = await _pump(tester);
    // ~11 m every 3 s => 100 fixes is ~1.1 km at ~3.7 m/s, so exactly one of
    // the three windows exists. Emitting them without a pump between each
    // would be faster, but the screen's own fix handling is what has to run.
    for (var n = 0; n <= 100; n++) {
      ctx.location.emitFix(_fixAt(n));
      await tester.pump();
    }

    final rect = tester.getRect(find.byKey(const Key('slideToFinishBar')));
    await tester.startGesture(rect.center);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();

    final persistedCardio = ctx.controller.finishCalls.single['cardio'] as CardioMetrics?;
    // 1000 m at ~3.7 m/s is ~270 s — a range, not an exact number: this test
    // is about the wiring, `best_effort_calculator_test.dart` owns the maths.
    expect(persistedCardio?.best1kSeconds, isNotNull);
    expect(persistedCardio!.best1kSeconds, inInclusiveRange(240, 300));
    // The run never reached these, so they must be absent rather than 0.
    expect(persistedCardio.best5kSeconds, isNull);
    expect(persistedCardio.best10kSeconds, isNull);
  });

  testWidgets('a run shorter than a km finishes with null best efforts, not zeroes',
      (tester) async {
    final ctx = await _pump(tester);
    ctx.location.emitFix(_fixAt(0));
    await tester.pump();
    ctx.location.emitFix(_fixAt(1));
    await tester.pump();

    final rect = tester.getRect(find.byKey(const Key('slideToFinishBar')));
    await tester.startGesture(rect.center);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();

    final persistedCardio = ctx.controller.finishCalls.single['cardio'] as CardioMetrics?;
    // The route itself was still recorded — only the best efforts are absent.
    expect(persistedCardio?.routePolyline, isNotNull);
    expect(persistedCardio!.best1kSeconds, isNull);
    expect(persistedCardio.best5kSeconds, isNull);
    expect(persistedCardio.best10kSeconds, isNull);
  });

  testWidgets('a MACHINE session finish never carries a route (no trail exists)', (tester) async {
    final ctx = await _pump(tester, session: _runningSession(clientId: 'bike-1', activityType: 'INDOOR_BIKE'));

    final rect = tester.getRect(find.byKey(const Key('slideToFinishBar')));
    await tester.startGesture(rect.center);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();

    final call = ctx.controller.finishCalls.single;
    expect(call['cardio'], isNull);
    expect(call['splits'], isNull);
  });

  testWidgets('finishing a hike with altitude data persists the peak as maxAltitudeMeters (C8.5)',
      (tester) async {
    final ctx = await _pump(tester,
        session: _runningSession(clientId: 'hike-1', activityType: 'HIKING'));
    // Climbs 5 m per fix, peaking at the last one.
    for (var n = 0; n <= 5; n++) {
      ctx.location.emitFix(_fixAt(n, altitude: 600 + n * 5));
      await tester.pump();
    }

    final rect = tester.getRect(find.byKey(const Key('slideToFinishBar')));
    await tester.startGesture(rect.center);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();

    final persistedCardio = ctx.controller.finishCalls.single['cardio'] as CardioMetrics?;
    expect(persistedCardio?.maxAltitudeMeters, 625);
  });

  testWidgets('finishing a hike with no altitude data leaves maxAltitudeMeters null, not zero',
      (tester) async {
    final ctx = await _pump(tester,
        session: _runningSession(clientId: 'hike-1', activityType: 'HIKING'));
    ctx.location.emitFix(_fixAt(0));
    await tester.pump();
    ctx.location.emitFix(_fixAt(1));
    await tester.pump();

    final rect = tester.getRect(find.byKey(const Key('slideToFinishBar')));
    await tester.startGesture(rect.center);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();

    final persistedCardio = ctx.controller.finishCalls.single['cardio'] as CardioMetrics?;
    expect(persistedCardio?.maxAltitudeMeters, isNull);
  });

  testWidgets(
      'finishing a hike with a climbing trail persists a non-null avgGapSecondsPerKm (C8.2 wiring)',
      (tester) async {
    final ctx = await _pump(tester,
        session: _runningSession(clientId: 'hike-1', activityType: 'HIKING'));
    // Same climbing fixture as the maxAltitudeMeters test above — the exact
    // grade-adjusted number is `grade_adjusted_pace_test.dart`'s job, this
    // test is only about the wiring: does `_finish()` call the formula and
    // persist the result at all.
    for (var n = 0; n <= 5; n++) {
      ctx.location.emitFix(_fixAt(n, altitude: 600 + n * 5));
      await tester.pump();
    }

    final rect = tester.getRect(find.byKey(const Key('slideToFinishBar')));
    await tester.startGesture(rect.center);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();

    final persistedCardio = ctx.controller.finishCalls.single['cardio'] as CardioMetrics?;
    expect(persistedCardio?.avgGapSecondsPerKm, isNotNull);
    expect(persistedCardio!.avgGapSecondsPerKm, greaterThan(0));
  });

  testWidgets(
      'a RUNNING session finish never computes avgGapSecondsPerKm — the field is hike-only (M42)',
      (tester) async {
    final ctx = await _pump(tester); // default activityType: RUNNING
    for (var n = 0; n <= 5; n++) {
      ctx.location.emitFix(_fixAt(n, altitude: 600 + n * 5));
      await tester.pump();
    }

    final rect = tester.getRect(find.byKey(const Key('slideToFinishBar')));
    await tester.startGesture(rect.center);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();

    final persistedCardio = ctx.controller.finishCalls.single['cardio'] as CardioMetrics?;
    expect(persistedCardio?.avgGapSecondsPerKm, isNull);
  });

  testWidgets('reopening a session with existing raw points replays them into the live distance '
      'immediately, without waiting for a new fix', (tester) async {
    final db = _testDatabase();
    final repo = CardioTrackPointRepository(db);
    final since = DateTime.now().subtract(const Duration(minutes: 5));
    await repo.addPoint(
      'live-1',
      0,
      LocationFix(latitude: 47.5, longitude: 19.05, recordedAt: since),
    );
    await repo.addPoint(
      'live-1',
      1,
      LocationFix(latitude: 47.501, longitude: 19.05, recordedAt: since.add(const Duration(seconds: 30))),
    );

    final controller = _RecordingSessionController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutSessionControllerProvider.overrideWith(() => controller),
          settingsControllerProvider.overrideWith(_MetricSettings.new),
          locationServiceProvider.overrideWithValue(_grantedLocationStub()),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CardioSessionScreen(session: _runningSession()),
        ),
      ),
    );
    // Let the async replay (pointsForSession) resolve.
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('km'), findsWidgets);
    expect(find.text('ESTIMATED'), findsNothing); // healthy, no gap yet
  });

  testWidgets('a rejected low-accuracy fix does not reset the weak-signal countdown',
      (tester) async {
    final ctx = await _pump(tester);
    ctx.location.emitFix(_fixAt(0));
    await tester.pump();
    ctx.location.emitFix(_fixAt(1));
    await tester.pump();

    // Halfway through the threshold, an inaccurate fix arrives — it must not
    // restart the countdown.
    await tester.pump(const Duration(seconds: 8));
    ctx.location.emitFix(LocationFix(
      latitude: 47.6, // real distance, but...
      longitude: 19.05,
      accuracy: 999, // ...unusably imprecise
      recordedAt: _epoch.add(const Duration(seconds: 30)),
    ));
    await tester.pump(const Duration(seconds: 8)); // total: 16s since the last *accepted* fix

    expect(find.text('Weak GPS'), findsOneWidget);
  });

  testWidgets('MACHINE sessions never show a GPS or weak-signal chip', (tester) async {
    await _pump(tester, session: _runningSession(clientId: 'bike-1', activityType: 'INDOOR_BIKE'));
    await tester.pump(_pastWeakSignalThreshold);

    expect(find.text('GPS'), findsNothing);
    expect(find.text('Weak GPS'), findsNothing);
  });
}
