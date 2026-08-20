import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/location/location_service.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/data/cardio_track_point_repository.dart';
import 'package:lifey/features/workouts/domain/route_encoder.dart';
import 'package:lifey/features/workouts/domain/track_filter.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_summary_screen.dart';
import 'package:lifey/features/workouts/presentation/widgets/route_painter.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// docs/cardio/60 C8.4 — the ÚTPONTOK list on the hike summary screen:
/// distance/altitude/elapsed matched against the session's own local track
/// (`matchWaypointsToTrail` owns the matching itself, tested separately in
/// `waypoint_track_match_test.dart`), falling back to the waypoint's own
/// stored altitude with dashes for the rest once that track is gone, plus
/// the numbered markers `RoutePainter` draws on the hero route card.

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

class _StubSessionController extends WorkoutSessionController {
  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);

  @override
  Future<void> updateLiveCardioMetrics(String clientId,
      {required DateTime startedAt, required CardioMetrics cardio}) async {}

  @override
  Future<void> rateSession(String clientId, {required int rpe, String? feedbackNote}) async {}
}

String _stubPolyline(int points) {
  final trail = [
    for (var i = 0; i <= points; i++)
      TrackFilterTrailPoint(
        latitude: 47.5 + i * 5 / 111320.0,
        longitude: 19.05,
        altitude: 100.0 + i,
        recordedAt: DateTime.utc(2026, 8, 19, 7, 0, i),
      ),
  ];
  return encodeRoute(trail).polyline;
}

WorkoutSession _hikeSession({List<CardioWaypoint> waypoints = const [], int polylinePoints = 5}) {
  return WorkoutSession(
    clientId: 'hike-1',
    exercises: const [],
    sets: const [],
    startedAt: DateTime.utc(2026, 8, 19, 7, 0, 0),
    finishedAt: DateTime.utc(2026, 8, 19, 7, 20, 0),
    sessionKind: 'CARDIO',
    activityType: 'HIKING',
    movingSeconds: 1200,
    cardio: CardioMetrics(
      distanceMeters: 1000,
      elevationGainMeters: 20,
      routePolyline: _stubPolyline(polylinePoints),
      routePointCount: polylinePoints + 1,
    ),
    waypoints: waypoints,
  );
}

/// Straight-line-north local track points, one per second, 5 m apart, flat
/// altitude — same shape `cardio_summary_screen_elevation_profile_test.dart`
/// uses, kept flat here since these tests are about distance/elapsed
/// matching, not the elevation profile.
Future<AppDatabase> _databaseWithTrack(String sessionClientId) async {
  final db = AppDatabase(NativeDatabase.memory());
  final repo = CardioTrackPointRepository(db);
  final t0 = DateTime.utc(2026, 8, 19, 7, 0, 0);
  for (var i = 0; i <= 200; i++) {
    await repo.addPoint(
      sessionClientId,
      i,
      LocationFix(
        latitude: 47.5 + i * 5 / 111320.0,
        longitude: 19.05,
        recordedAt: t0.add(Duration(seconds: i)),
        altitude: 612,
        accuracy: 5,
      ),
    );
  }
  return db;
}

Future<AppDatabase> _emptyDatabase() async => AppDatabase(NativeDatabase.memory());

Future<void> _pump(WidgetTester tester, WorkoutSession session, AppDatabase db) async {
  await tester.binding.setSurfaceSize(const Size(400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsControllerProvider.overrideWith(_MetricSettings.new),
        workoutSessionControllerProvider.overrideWith(_StubSessionController.new),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CardioSummaryScreen(session: session),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('with local track points available', () {
    testWidgets('shows the ÚTPONTOK list with distance/altitude/elapsed matched to the track',
        (tester) async {
      final db = await _databaseWithTrack('hike-1');
      addTearDown(db.close);
      // Point 40 of the seeded track sits 200 m in (40 * 5 m), at t=40s.
      final waypoints = [
        const CardioWaypoint(
          waypointIndex: 0,
          latitude: 47.5 + 40 * 5 / 111320.0,
          longitude: 19.05,
        ),
      ];

      await _pump(tester, _hikeSession(waypoints: waypoints), db);

      expect(tester.takeException(), isNull);
      expect(find.text('WAYPOINTS'), findsOneWidget);
      expect(find.text('1 waypoints'), findsOneWidget);
      expect(find.textContaining('0.20 km'), findsWidgets);
      expect(find.textContaining('612 m'), findsWidgets); // the track's own altitude
      expect(find.textContaining('0:40'), findsWidgets);
    });

    testWidgets('renders numbered markers on the hero route card', (tester) async {
      final db = await _emptyDatabase();
      addTearDown(db.close);
      final waypoints = [
        const CardioWaypoint(waypointIndex: 0, latitude: 47.5, longitude: 19.05),
        const CardioWaypoint(waypointIndex: 1, latitude: 47.501, longitude: 19.05),
      ];

      await _pump(tester, _hikeSession(waypoints: waypoints), db);

      expect(tester.takeException(), isNull);
      final painter = tester.widget<RoutePainter>(find.byType(RoutePainter));
      expect(painter.waypoints, hasLength(2));
    });

    testWidgets('50 waypoints render without throwing (perf kész-ha)', (tester) async {
      final db = await _emptyDatabase();
      addTearDown(db.close);
      final waypoints = [
        for (var i = 0; i < 50; i++)
          CardioWaypoint(waypointIndex: i, latitude: 47.5 + i * 0.0001, longitude: 19.05),
      ];

      await _pump(tester, _hikeSession(waypoints: waypoints, polylinePoints: 60), db);

      expect(tester.takeException(), isNull);
      expect(find.text('50 waypoints'), findsOneWidget);
    });
  });

  group('without local track points', () {
    testWidgets('falls back to the waypoint\'s own stored altitude, dashes for the rest',
        (tester) async {
      final db = await _emptyDatabase();
      addTearDown(db.close);
      final waypoints = [
        const CardioWaypoint(
            waypointIndex: 0, latitude: 47.5, longitude: 19.05, altitudeMeters: 640),
      ];

      await _pump(tester, _hikeSession(waypoints: waypoints), db);

      expect(tester.takeException(), isNull);
      expect(find.text('WAYPOINTS'), findsOneWidget);
      expect(find.textContaining('640 m'), findsWidgets);
      expect(find.textContaining('— · '), findsOneWidget);
    });
  });

  testWidgets('no waypoints: the section is absent entirely', (tester) async {
    final db = await _emptyDatabase();
    addTearDown(db.close);

    await _pump(tester, _hikeSession(), db);

    expect(find.text('WAYPOINTS'), findsNothing);
  });

  testWidgets('a RUNNING session never shows the ÚTPONTOK section, even with waypoints in state',
      (tester) async {
    final db = await _emptyDatabase();
    addTearDown(db.close);
    final session = WorkoutSession(
      clientId: 'run-1',
      exercises: const [],
      sets: const [],
      startedAt: DateTime.utc(2026, 8, 19, 7),
      finishedAt: DateTime.utc(2026, 8, 19, 7, 20),
      sessionKind: 'CARDIO',
      activityType: 'RUNNING',
      movingSeconds: 1200,
      cardio: CardioMetrics(distanceMeters: 1000, routePolyline: _stubPolyline(5), routePointCount: 6),
      waypoints: const [
        CardioWaypoint(waypointIndex: 0, latitude: 47.5, longitude: 19.05),
      ],
    );

    await _pump(tester, session, db);

    expect(find.text('WAYPOINTS'), findsNothing);
  });
}
