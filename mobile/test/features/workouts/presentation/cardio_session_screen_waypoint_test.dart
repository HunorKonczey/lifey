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
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_session_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// docs/cardio/60 C8.4, M41 — the live hike screen's waypoint marker button:
/// HIKING-only, disabled-not-hidden without GPS, a 4 s auto-dismissing
/// "N. útpont megjelölve" confirmation with "Vissza" undo, and every mark
/// persisted through `WorkoutSessionController.updateLiveWaypoints` as a
/// full-replace. Mirrors `cardio_session_screen_gps_tracking_test.dart`'s
/// `LocationServiceStub` fixture pattern.

class _RecordingSessionController extends WorkoutSessionController {
  final waypointCalls = <List<CardioWaypoint>>[];

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);

  @override
  Future<void> pauseCardioSession(String clientId,
      {required DateTime startedAt, required int movingSeconds}) async {}

  @override
  Future<void> resumeCardioSession(String clientId,
      {required DateTime startedAt, required DateTime resumedAt}) async {}

  @override
  Future<void> updateLiveCardioMetrics(String clientId,
      {required DateTime startedAt, required CardioMetrics cardio}) async {}

  @override
  Future<void> finishCardioSession(String clientId,
      {required DateTime startedAt,
      required DateTime finishedAt,
      required int movingSeconds,
      Value<CardioMetrics?> cardio = const Value.absent(),
      Value<List<CardioSplit>> splits = const Value.absent()}) async {}

  @override
  Future<void> updateLiveWaypoints(String clientId,
      {required DateTime startedAt, required List<CardioWaypoint> waypoints}) async {
    waypointCalls.add(waypoints);
  }
}

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

WorkoutSession _liveSession({String activityType = 'HIKING'}) {
  final since = DateTime.now().subtract(const Duration(minutes: 5));
  return WorkoutSession(
    clientId: 'hike-live-1',
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

final _epoch = DateTime.utc(2026, 8, 19, 7, 0, 0);

LocationFix _fixAt(int n, {double altitude = 612}) => LocationFix(
      latitude: 47.5 + n * 0.0001,
      longitude: 19.05,
      altitude: altitude,
      recordedAt: _epoch.add(Duration(seconds: n * 3)),
    );

/// A fresh in-memory database per pump — without this override every pump
/// here falls through to the real, path_provider-backed default (the
/// `_seedTrackPointSeqAndSync`/`cardioTrackPointRepositoryProvider` read in
/// `initState` needs one), same fix `cardio_summary_screen_test.dart` and
/// `cardio_summary_screen_elevation_profile_test.dart` already apply.
AppDatabase _testDatabase() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

Future<_RecordingSessionController> _pump(
  WidgetTester tester, {
  WorkoutSession? session,
  LocationServiceStub? location,
}) async {
  final controller = _RecordingSessionController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => controller),
        settingsControllerProvider.overrideWith(_MetricSettings.new),
        locationServiceProvider.overrideWithValue(location ?? _grantedLocationStub()),
        appDatabaseProvider.overrideWithValue(_testDatabase()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CardioSessionScreen(session: session ?? _liveSession()),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  testWidgets('the marker button is absent for a RUNNING session', (tester) async {
    await _pump(tester, session: _liveSession(activityType: 'RUNNING'));
    expect(find.byKey(const Key('waypointMarkButton')), findsNothing);
  });

  testWidgets('the marker button appears for a HIKING session', (tester) async {
    await _pump(tester, session: _liveSession());
    expect(find.byKey(const Key('waypointMarkButton')), findsOneWidget);
    expect(find.text('Mark waypoint'), findsOneWidget);
    expect(find.text('where you are now'), findsOneWidget);
  });

  testWidgets('without GPS the button stays visible but shows the unavailable state',
      (tester) async {
    final denied = LocationServiceStub(
      initial: const LocationAvailability(
        authorization: LocationAuthorization.denied,
        precise: false,
        serviceEnabled: true,
      ),
    );
    final controller = await _pump(tester, location: denied);

    expect(find.byKey(const Key('waypointMarkButton')), findsOneWidget);
    expect(find.text('no location, nothing to mark'), findsOneWidget);

    await tester.tap(find.byKey(const Key('waypointMarkButton')));
    await tester.pumpAndSettle();

    expect(controller.waypointCalls, isEmpty);
  });

  testWidgets('tapping with a fix marks a waypoint, shows the feedback banner, persists it',
      (tester) async {
    final controller = await _pump(tester);
    // A fix must arrive before the button does anything (nothing to mark
    // yet) — emitted the same way the GPS-tracking tests do.
    final stub = ProviderScope.containerOf(tester.element(find.byType(CardioSessionScreen)))
        .read(locationServiceProvider) as LocationServiceStub;
    stub.emitFix(_fixAt(0));
    await tester.pump();

    await tester.tap(find.byKey(const Key('waypointMarkButton')));
    await tester.pump();

    expect(find.byKey(const Key('waypointMarkedBanner')), findsOneWidget);
    expect(find.text('Waypoint 1 marked'), findsOneWidget);
    expect(controller.waypointCalls, hasLength(1));
    final marked = controller.waypointCalls.single.single;
    expect(marked.waypointIndex, 0);
    expect(marked.altitudeMeters, 612);
  });

  testWidgets('Undo removes exactly the mark just made', (tester) async {
    final controller = await _pump(tester);
    final stub = ProviderScope.containerOf(tester.element(find.byType(CardioSessionScreen)))
        .read(locationServiceProvider) as LocationServiceStub;
    stub.emitFix(_fixAt(0));
    await tester.pump();
    await tester.tap(find.byKey(const Key('waypointMarkButton')));
    await tester.pump();
    expect(find.byKey(const Key('waypointMarkedBanner')), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(find.byKey(const Key('waypointMarkedBanner')), findsNothing);
    expect(controller.waypointCalls.last, isEmpty);
  });

  testWidgets('the banner auto-dismisses after 4 seconds, leaving the mark in place',
      (tester) async {
    final controller = await _pump(tester);
    final stub = ProviderScope.containerOf(tester.element(find.byType(CardioSessionScreen)))
        .read(locationServiceProvider) as LocationServiceStub;
    stub.emitFix(_fixAt(0));
    await tester.pump();
    await tester.tap(find.byKey(const Key('waypointMarkButton')));
    await tester.pump();
    expect(find.byKey(const Key('waypointMarkedBanner')), findsOneWidget);

    await tester.pump(const Duration(seconds: 4, milliseconds: 100));

    expect(find.byKey(const Key('waypointMarkedBanner')), findsNothing);
    expect(controller.waypointCalls.last, hasLength(1)); // the mark itself wasn't undone
  });

  testWidgets('marking twice assigns sequential indices and keeps both', (tester) async {
    final controller = await _pump(tester);
    final stub = ProviderScope.containerOf(tester.element(find.byType(CardioSessionScreen)))
        .read(locationServiceProvider) as LocationServiceStub;
    stub.emitFix(_fixAt(0));
    await tester.pump();
    await tester.tap(find.byKey(const Key('waypointMarkButton')));
    await tester.pump(const Duration(seconds: 5)); // let the first banner clear
    stub.emitFix(_fixAt(1));
    await tester.pump();
    await tester.tap(find.byKey(const Key('waypointMarkButton')));
    await tester.pump();

    expect(controller.waypointCalls.last, hasLength(2));
    expect(controller.waypointCalls.last[0].waypointIndex, 0);
    expect(controller.waypointCalls.last[1].waypointIndex, 1);
    expect(find.text('Waypoint 2 marked'), findsOneWidget);
  });
}
