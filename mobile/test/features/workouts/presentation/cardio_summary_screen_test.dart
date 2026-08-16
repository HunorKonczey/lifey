import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/cardio_personal_record.dart';
import 'package:lifey/features/workouts/domain/route_encoder.dart';
import 'package:lifey/features/workouts/domain/track_filter.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_summary_screen.dart';
import 'package:lifey/features/workouts/presentation/widgets/route_painter.dart';
import 'package:lifey/features/workouts/presentation/workouts_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// C1.9 → C2.8: `CardioSummaryScreen` — started read-only (C1.9), now the
/// full editable summary (C2.8, M14/M15). docs/cardio/59-cardio-implementation-plan.md
/// C2.8 — kész-ha: "A szerkesztett érték felülírja a mértet, és jelölve
/// marad" (the edited value overwrites the measured one, and stays marked).
///
/// Only [CardioMetrics.distanceMeters]/[CardioMetrics.deviceCalories] carry
/// a real provenance field today (`distanceSource`/`caloriesSource` — see
/// the screen's own class doc for why); those are what get edit+badge
/// coverage below. Everything else (cadence, watts, resistance, elevation,
/// GAME fields) stays read-only, unchanged from C1.9's tests.

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

class _RecordingSessionController extends WorkoutSessionController {
  final updateLiveCardioMetricsCalls = <Map<String, Object?>>[];
  final rateCalls = <Map<String, Object?>>[];
  bool failNext = false;

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);

  @override
  Future<void> updateLiveCardioMetrics(
    String clientId, {
    required DateTime startedAt,
    required CardioMetrics cardio,
  }) async {
    if (failNext) throw Exception('boom');
    updateLiveCardioMetricsCalls.add({'clientId': clientId, 'startedAt': startedAt, 'cardio': cardio});
  }

  @override
  Future<void> rateSession(String clientId, {required int rpe, String? feedbackNote}) async {
    if (failNext) throw Exception('boom');
    rateCalls.add({'clientId': clientId, 'rpe': rpe, 'feedbackNote': feedbackNote});
  }
}

Future<_RecordingSessionController> _pump(
  WidgetTester tester,
  WorkoutSession session, {
  List<CardioPrType> newRecords = const [],
}) async {
  final controller = _RecordingSessionController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsControllerProvider.overrideWith(_MetricSettings.new),
        workoutSessionControllerProvider.overrideWith(() => controller),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CardioSummaryScreen(session: session, newRecords: newRecords),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

WorkoutSession _session({
  required String activityType,
  CardioMetrics? cardio,
  int? movingSeconds,
  int? rpe,
  String? feedbackNote,
}) {
  final startedAt = DateTime(2026, 8, 10, 7);
  return WorkoutSession(
    clientId: 'c1',
    exercises: const [],
    sets: const [],
    startedAt: startedAt,
    finishedAt: startedAt.add(Duration(seconds: movingSeconds ?? 0)),
    sessionKind: 'CARDIO',
    activityType: activityType,
    movingSeconds: movingSeconds,
    cardio: cardio,
    rpe: rpe,
    feedbackNote: feedbackNote,
  );
}

/// A real encoded route (not a hand-crafted string) from a small synthetic
/// trail — 2.2 km straight north, climbing steadily — so C4a.6's UI tests
/// exercise the actual `route_encoder.dart` pipeline, same as production.
({String polyline, List<CardioSplit> splits}) _testRoute() {
  final t0 = DateTime.utc(2026, 8, 10, 7, 0, 0);
  final trail = [
    for (var i = 0; i <= 440; i++)
      TrackFilterTrailPoint(
        latitude: 47.5 + (i * 5) / 111320.0,
        longitude: 19.05,
        altitude: 100 + i * 0.1,
        recordedAt: t0.add(Duration(seconds: i)),
      ),
  ];
  final encoded = encodeRoute(trail);
  return (
    polyline: encoded.polyline,
    splits: const [
      CardioSplit(splitIndex: 0, distanceMeters: 1000, durationSeconds: 200, elevationDeltaM: 20),
      CardioSplit(splitIndex: 1, distanceMeters: 1000, durationSeconds: 200, elevationDeltaM: 20),
      CardioSplit(splitIndex: 2, distanceMeters: 200, durationSeconds: 40, elevationDeltaM: 4),
    ],
  );
}

void main() {
  group('route / elevation profile / splits (C4a.6)', () {
    testWidgets('a DISTANCE session with a route shows the route painter and split list',
        (tester) async {
      // The route/elevation/splits block pushes this screen's content well
      // past the default 800x600 test surface — without a taller surface,
      // ListView's virtualization simply never builds the SPLITS section's
      // Elements, and find.text would report a false negative.
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final route = _testRoute();
      await _pump(
        tester,
        WorkoutSession(
          clientId: 'c1',
          exercises: const [],
          sets: const [],
          startedAt: DateTime(2026, 8, 10, 7),
          finishedAt: DateTime(2026, 8, 10, 7, 30),
          sessionKind: 'CARDIO',
          activityType: 'RUNNING',
          movingSeconds: 1800,
          cardio: CardioMetrics(
            distanceMeters: 5000,
            elevationGainMeters: 44,
            routePolyline: route.polyline,
            routePointCount: 50,
          ),
          splits: route.splits,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(RoutePainter), findsOneWidget);
      expect(find.text('ELEVATION PROFILE'), findsOneWidget);
      expect(find.text('SPLITS'), findsOneWidget);
      // M14's split row is index + bar + one number: a full kilometre shows
      // its time (which, over 1 km, *is* its pace), and the short remainder
      // shows the distance it actually covered instead — "így nem tűnik
      // hirtelen belassulásnak". Plain digit texts ('1', '2', '3') aren't
      // asserted here since the RPE chip row below also renders those.
      expect(find.text('3:20'), findsNWidgets(2)); // splits 0 and 1
      expect(find.text('1.00 km'), findsNothing); // the bar carries the length now
      expect(find.text('0.20 km'), findsOneWidget); // split 2 (the shorter remainder)
    });

    testWidgets('a DISTANCE session without a route shows none of the C4a.6 sections',
        (tester) async {
      await _pump(
        tester,
        _session(activityType: 'RUNNING', cardio: const CardioMetrics(distanceMeters: 5000)),
      );

      expect(find.byType(RoutePainter), findsNothing);
      expect(find.text('SPLITS'), findsNothing);
    });

    testWidgets('a route with no altitude data (elevationGainMeters null) skips the profile chart',
        (tester) async {
      final route = _testRoute();
      await _pump(
        tester,
        WorkoutSession(
          clientId: 'c1',
          exercises: const [],
          sets: const [],
          startedAt: DateTime(2026, 8, 10, 7),
          finishedAt: DateTime(2026, 8, 10, 7, 30),
          sessionKind: 'CARDIO',
          activityType: 'RUNNING',
          movingSeconds: 1800,
          cardio: CardioMetrics(distanceMeters: 5000, routePolyline: route.polyline),
        ),
      );

      expect(find.byType(RoutePainter), findsOneWidget); // the route itself still shows
      expect(find.text('ELEVATION PROFILE'), findsNothing);
    });

    testWidgets('editing distance preserves the route — a full-replace write must not erase it',
        (tester) async {
      final route = _testRoute();
      final controller = await _pump(
        tester,
        WorkoutSession(
          clientId: 'c1',
          exercises: const [],
          sets: const [],
          startedAt: DateTime(2026, 8, 10, 7),
          finishedAt: DateTime(2026, 8, 10, 7, 30),
          sessionKind: 'CARDIO',
          activityType: 'RUNNING',
          movingSeconds: 1800,
          cardio: CardioMetrics(
            distanceMeters: 5000,
            routePolyline: route.polyline,
            routePointCount: 50,
          ),
        ),
      );

      await tester.tap(find.text('5.00 km'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '5.2');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final cardio = controller.updateLiveCardioMetricsCalls.single['cardio'] as CardioMetrics;
      expect(cardio.routePolyline, route.polyline);
      expect(cardio.routePointCount, 50);
    });
  });

  group('new-record banner (C3.5)', () {
    testWidgets('shows one line per broken record type when newRecords is non-empty',
        (tester) async {
      await _pump(
        tester,
        _session(activityType: 'RUNNING', cardio: const CardioMetrics(distanceMeters: 5000)),
        newRecords: const [CardioPrType.longestDistance, CardioPrType.longestMovingTime],
      );

      expect(find.text('New personal record!'), findsOneWidget);
      expect(find.text('Longest distance · Longest moving time'), findsOneWidget);
    });

    testWidgets('shows nothing when newRecords is empty (e.g. reopening a past session)',
        (tester) async {
      await _pump(
        tester,
        _session(activityType: 'RUNNING', cardio: const CardioMetrics(distanceMeters: 5000)),
      );

      expect(find.text('New personal record!'), findsNothing);
    });
  });

  testWidgets('DISTANCE with a recorded distance shows distance as primary, pace as secondary',
      (tester) async {
    await _pump(
      tester,
      _session(
        activityType: 'RUNNING',
        cardio: const CardioMetrics(distanceMeters: 5000, elevationGainMeters: 42),
        movingSeconds: 1500, // 25:00 -> 5:00 /km
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('DISTANCE'), findsOneWidget);
    expect(find.text('5.00 km'), findsOneWidget);
    expect(find.text('PACE'), findsOneWidget);
    expect(find.text('5:00 /km'), findsOneWidget);
    expect(find.text('ELEVATION GAIN'), findsOneWidget);
    expect(find.text('42 m'), findsOneWidget);
    // Never entered by hand, no badge.
    expect(find.text('Edited'), findsNothing);
  });

  testWidgets('DISTANCE without a recorded distance falls back to duration as primary',
      (tester) async {
    await _pump(tester, _session(activityType: 'WALKING', movingSeconds: 1800));

    expect(find.text('DURATION'), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget);
    expect(find.text('PACE'), findsNothing);
  });

  testWidgets('a manually-entered distance shows the Edited badge', (tester) async {
    await _pump(
      tester,
      _session(
        activityType: 'RUNNING',
        cardio: const CardioMetrics(distanceMeters: 5000, distanceSource: 'MANUAL'),
        movingSeconds: 1500,
      ),
    );

    expect(find.text('Edited'), findsOneWidget);
  });

  testWidgets('MACHINE always shows moving time as primary, never distance', (tester) async {
    await _pump(
      tester,
      _session(
        activityType: 'INDOOR_BIKE',
        cardio: const CardioMetrics(
          distanceMeters: 18400,
          avgWatts: 164,
          avgCadence: 81,
          // Deliberately outside the 1-10 RPE chip range so this doesn't
          // collide with a chip label when disambiguating find.text('14').
          resistanceLevel: 14,
          deviceCalories: 420,
        ),
        movingSeconds: 2538,
      ),
    );

    expect(find.text('MOVING TIME'), findsOneWidget);
    expect(find.text('42:18'), findsOneWidget);
    expect(find.text('DISTANCE'), findsOneWidget); // secondary tile, not primary
    expect(find.text('18.40 km'), findsOneWidget);
    expect(find.text('164 W'), findsOneWidget);
    expect(find.text('81 rpm'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('420 kcal'), findsOneWidget);
  });

  testWidgets('GAME shows playing time as primary and its own fields as secondary',
      (tester) async {
    await _pump(
      tester,
      _session(
        activityType: 'BASKETBALL',
        cardio: const CardioMetrics(intensity: 4, venue: 'INDOOR', scorePoints: 18),
        movingSeconds: 3120,
      ),
    );

    expect(find.text('PLAYING TIME'), findsOneWidget);
    expect(find.text('52:00'), findsOneWidget);
    expect(find.text('VENUE'), findsOneWidget);
    expect(find.text('Indoor'), findsOneWidget);
    expect(find.text('INTENSITY'), findsOneWidget);
    expect(find.text('4/5'), findsOneWidget);
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
  });

  group('feedback (RPE + note) — always visible and editable, C2.8', () {
    testWidgets('an unrated session still shows the feedback card, ready to rate', (tester) async {
      await _pump(tester, _session(activityType: 'RUNNING', movingSeconds: 600));

      expect(find.text('How hard was this workout?'), findsOneWidget);
    });

    testWidgets('a rated session shows the note text', (tester) async {
      await _pump(
        tester,
        _session(
          activityType: 'RUNNING',
          movingSeconds: 600,
          rpe: 7,
          feedbackNote: 'Felt great',
        ),
      );

      expect(find.text('How hard was this workout?'), findsOneWidget);
      expect(find.text('Felt great'), findsOneWidget);
    });

    testWidgets('tapping an RPE chip rates the session immediately', (tester) async {
      final controller = await _pump(tester, _session(activityType: 'RUNNING', movingSeconds: 600));

      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();

      expect(controller.rateCalls, hasLength(1));
      expect(controller.rateCalls.single['rpe'], 7);
      expect(controller.rateCalls.single['feedbackNote'], isNull);
    });

    testWidgets('typing a note after rating saves both once the field loses focus',
        (tester) async {
      final controller = await _pump(tester, _session(activityType: 'RUNNING', movingSeconds: 600));

      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Legs felt heavy');
      // Losing focus (not the text change itself) triggers the save.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(controller.rateCalls, hasLength(2));
      expect(controller.rateCalls.last['rpe'], 7);
      expect(controller.rateCalls.last['feedbackNote'], 'Legs felt heavy');
    });

    testWidgets('typing a note before ever rating does not call rateSession', (tester) async {
      final controller = await _pump(tester, _session(activityType: 'RUNNING', movingSeconds: 600));

      await tester.enterText(find.byType(TextField), 'no rating yet');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(controller.rateCalls, isEmpty);
    });
  });

  group('manual metric editing — R8 "manual overwrites measured, stays marked"', () {
    testWidgets('editing distance persists the new value and shows the Edited badge',
        (tester) async {
      final controller = await _pump(
        tester,
        _session(activityType: 'RUNNING', cardio: const CardioMetrics(distanceMeters: 5000)),
      );
      expect(find.text('Edited'), findsNothing);

      await tester.tap(find.text('5.00 km'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '6.5');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(controller.updateLiveCardioMetricsCalls, hasLength(1));
      final cardio = controller.updateLiveCardioMetricsCalls.single['cardio'] as CardioMetrics;
      expect(cardio.distanceMeters, 6500);
      expect(cardio.distanceSource, 'MANUAL');
      expect(find.text('6.50 km'), findsOneWidget);
      expect(find.text('Edited'), findsOneWidget);
    });

    testWidgets('editing distance preserves the other MACHINE fields already on the session',
        (tester) async {
      final controller = await _pump(
        tester,
        _session(
          activityType: 'INDOOR_BIKE',
          cardio: const CardioMetrics(distanceMeters: 18400, avgWatts: 164, avgCadence: 81),
        ),
      );

      await tester.tap(find.text('18.40 km'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '20');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final cardio = controller.updateLiveCardioMetricsCalls.single['cardio'] as CardioMetrics;
      expect(cardio.distanceMeters, 20000);
      expect(cardio.avgWatts, 164); // not clobbered
      expect(cardio.avgCadence, 81); // not clobbered
    });

    testWidgets('editing MACHINE device calories persists and marks the tile edited',
        (tester) async {
      // distanceMeters set so the distance tile isn't *also* showing the
      // '—' placeholder — deviceCalories is then the only ambiguous match.
      final controller = await _pump(
        tester,
        _session(
          activityType: 'INDOOR_BIKE',
          cardio: const CardioMetrics(distanceMeters: 1000, avgWatts: 150),
        ),
      );

      await tester.tap(find.text('—')); // deviceCalories placeholder tile
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '350');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final cardio = controller.updateLiveCardioMetricsCalls.single['cardio'] as CardioMetrics;
      expect(cardio.deviceCalories, 350);
      expect(cardio.caloriesSource, 'MANUAL');
      expect(find.text('350 kcal'), findsOneWidget);
      expect(find.text('Edited'), findsOneWidget);
    });

    testWidgets('a failed edit shows an error and keeps the previous value', (tester) async {
      final controller = await _pump(
        tester,
        _session(activityType: 'RUNNING', cardio: const CardioMetrics(distanceMeters: 5000)),
      );
      controller.failNext = true;

      await tester.tap(find.text('5.00 km'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '9');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('5.00 km'), findsOneWidget);
      expect(find.text('9.00 km'), findsNothing);
    });
  });

  group('Done button', () {
    testWidgets('requests the Sessions tab (no GoRouter ancestor: falls back to a no-op pop)',
        (tester) async {
      final container = ProviderContainer(overrides: [
        settingsControllerProvider.overrideWith(_MetricSettings.new),
        workoutSessionControllerProvider.overrideWith(_RecordingSessionController.new),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CardioSummaryScreen(
              session: _session(activityType: 'RUNNING', cardio: const CardioMetrics(distanceMeters: 5000)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(workoutsSessionsTabRequestProvider), 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      expect(container.read(workoutsSessionsTabRequestProvider), 1);
    });
  });
}
