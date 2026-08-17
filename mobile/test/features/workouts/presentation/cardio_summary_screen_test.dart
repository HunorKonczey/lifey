import 'dart:async';

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
import 'package:lifey/shared/widgets/charts/pace_bar_chart.dart';

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
  CardioPrBaseline previousBests = CardioPrBaseline.empty,
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
        home: CardioSummaryScreen(
          session: session,
          newRecords: newRecords,
          previousBests: previousBests,
        ),
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

/// A finished RUNNING session carrying [route]'s polyline, with its split
/// list overridable — the C6.4 cases differ only in what the splits look
/// like (one split, no altitude, a signed delta).
WorkoutSession _routedSession(
  ({String polyline, List<CardioSplit> splits}) route, {
  List<CardioSplit>? splits,
}) {
  return WorkoutSession(
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
    splits: splits ?? route.splits,
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

    testWidgets('the pace chart and the split list are driven by one selection (C6.4, M33)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final route = _testRoute();
      await _pump(tester, _routedSession(route));

      expect(find.text('PACE PER SPLIT'), findsOneWidget);
      expect(find.byType(PaceBarChart), findsOneWidget);
      expect(tester.widget<PaceBarChart>(find.byType(PaceBarChart)).selectedIndex, isNull);

      // Tapping the *list* row moves the *chart's* selection — that shared
      // index is the "egy adat két nézete" claim, made structurally.
      await tester.tap(find.text('3:20').first);
      await tester.pumpAndSettle();
      expect(tester.widget<PaceBarChart>(find.byType(PaceBarChart)).selectedIndex, 0);

      // Tapping the same row again clears it rather than sticking.
      await tester.tap(find.text('3:20').first);
      await tester.pumpAndSettle();
      expect(tester.widget<PaceBarChart>(find.byType(PaceBarChart)).selectedIndex, isNull);
    });

    testWidgets('the chart feeds on the same split list the rows do', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final route = _testRoute();
      await _pump(tester, _routedSession(route));

      final bars = tester.widget<PaceBarChart>(find.byType(PaceBarChart)).bars;
      expect(bars, hasLength(route.splits.length));
      expect([for (final b in bars) b.durationSeconds],
          [for (final s in route.splits) s.durationSeconds]);
      // The 200 m remainder is the only one marked partial — it must not be
      // scored as the fastest split of the run.
      expect([for (final b in bars) b.partial], [false, false, true]);
    });

    testWidgets('a single split gets a list but no chart', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final route = _testRoute();
      await _pump(
        tester,
        _routedSession(route, splits: const [
          CardioSplit(
              splitIndex: 0, distanceMeters: 1000, durationSeconds: 200, elevationDeltaM: 20),
        ]),
      );

      // Nothing to compare one bar against, and the average line would run
      // straight through it.
      expect(find.byType(PaceBarChart), findsNothing);
      expect(find.text('PACE PER SPLIT'), findsNothing);
      expect(find.text('SPLITS'), findsOneWidget);
    });

    testWidgets('split rows carry the elevation delta, signed', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final route = _testRoute();
      await _pump(
        tester,
        _routedSession(route, splits: const [
          CardioSplit(
              splitIndex: 0, distanceMeters: 1000, durationSeconds: 200, elevationDeltaM: 20),
          CardioSplit(
              splitIndex: 1, distanceMeters: 1000, durationSeconds: 210, elevationDeltaM: -4),
        ]),
      );

      expect(find.text('+20 m'), findsOneWidget);
      expect(find.text('−4 m'), findsOneWidget);
      expect(find.text('No elevation data'), findsNothing);
    });

    testWidgets('a run with no altitude data says so once, instead of blanking every row',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final route = _testRoute();
      await _pump(
        tester,
        _routedSession(route, splits: const [
          CardioSplit(splitIndex: 0, distanceMeters: 1000, durationSeconds: 200),
          CardioSplit(splitIndex: 1, distanceMeters: 1000, durationSeconds: 210),
        ]),
      );

      expect(find.text('No elevation data'), findsOneWidget);
      // The list itself still works — only the elevation column is absent.
      expect(find.text('3:20'), findsOneWidget);
      expect(find.text('3:30'), findsOneWidget);
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

  group('running cadence (C6.5)', () {
    testWidgets('a run shows the cadence the watch measured, in steps per minute',
        (tester) async {
      await _pump(
        tester,
        _session(
          activityType: 'RUNNING',
          movingSeconds: 1800,
          cardio: const CardioMetrics(distanceMeters: 5000, avgCadence: 172),
        ),
      );

      expect(find.text('172 spm'), findsOneWidget);
      // The indoor bike's unit must not leak onto a run.
      expect(find.text('172 rpm'), findsNothing);
    });

    testWidgets('a run with no cadence data shows no cadence tile at all', (tester) async {
      // The kész-ha: it appears only when a sensor genuinely sent it — no
      // placeholder dash, no empty tile.
      await _pump(
        tester,
        _session(
          activityType: 'RUNNING',
          movingSeconds: 1800,
          cardio: const CardioMetrics(distanceMeters: 5000),
        ),
      );

      expect(find.text('CADENCE'), findsNothing);
      expect(find.textContaining('spm'), findsNothing);
    });

    testWidgets('a walk never shows cadence, even when one was measured', (tester) async {
      // Steps per minute is a number a walker doesn't train on — the metric
      // belongs to running, so the tile doesn't exist here.
      await _pump(
        tester,
        _session(
          activityType: 'WALKING',
          movingSeconds: 2400,
          cardio: const CardioMetrics(distanceMeters: 3000, avgCadence: 118),
        ),
      );

      expect(find.textContaining('spm'), findsNothing);
      expect(find.text('118 spm'), findsNothing);
    });

    testWidgets('a hike never shows cadence either', (tester) async {
      await _pump(
        tester,
        _session(
          activityType: 'HIKING',
          movingSeconds: 5400,
          cardio: const CardioMetrics(distanceMeters: 8000, avgCadence: 110),
        ),
      );

      expect(find.textContaining('spm'), findsNothing);
    });

    testWidgets('the indoor bike keeps its own rpm cadence, untouched', (tester) async {
      await _pump(
        tester,
        _session(
          activityType: 'INDOOR_BIKE',
          movingSeconds: 2700,
          cardio: const CardioMetrics(avgCadence: 88, avgWatts: 160),
        ),
      );

      expect(find.text('88 rpm'), findsOneWidget);
      expect(find.textContaining('spm'), findsNothing);
    });
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

    testWidgets('dismisses the screen it was pushed onto', (tester) async {
      // The real shape of both entry points: this screen is pushed straight
      // onto the navigator (by `CardioSessionScreen._finish`'s
      // `pushReplacement`, or by `open_workout_screens.dart`), so it is a
      // *pageless* route sitting above go_router's own pages. Done used to
      // only call `context.go('/workouts')`, which rebuilds those pages but
      // never pops a route on top of them — and after finishing, the location
      // already *was* `/workouts`, so the button did nothing whatsoever.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsControllerProvider.overrideWith(_MetricSettings.new),
            workoutSessionControllerProvider.overrideWith(_RecordingSessionController.new),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Text('behind')),
          ),
        ),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(navigator.push(MaterialPageRoute<void>(
        builder: (_) => CardioSummaryScreen(
          session: _session(
            activityType: 'WALKING',
            cardio: const CardioMetrics(distanceMeters: 5000),
          ),
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.byType(CardioSummaryScreen), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.byType(CardioSummaryScreen), findsNothing);
      expect(find.text('behind'), findsOneWidget);
    });
  });

  // -- Best efforts + record celebration (C6.7, M34/M36) -------------------

  group('best efforts card', () {
    WorkoutSession runWithBestEfforts({
      int? best1k = 250,
      int? best5k = 1400,
      int? best10k = 2980,
      String activityType = 'RUNNING',
    }) {
      return _session(
        activityType: activityType,
        movingSeconds: 3600,
        cardio: CardioMetrics(
          distanceMeters: 12000,
          best1kSeconds: best1k,
          best5kSeconds: best5k,
          best10kSeconds: best10k,
        ),
      );
    }

    testWidgets('lists each sub-distance with its time and normalized pace', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pump(tester, runWithBestEfforts());

      expect(find.text('BEST EFFORTS'), findsOneWidget);
      expect(find.text('Fastest 1 km'), findsOneWidget);
      expect(find.text('4:10'), findsOneWidget); // 250 s
      expect(find.text('23:20'), findsOneWidget); // 1400 s
      expect(find.text('49:40'), findsOneWidget); // 2980 s
      // Only the pace is comparable across the three rows: 1400 s over 5 km
      // is 4:40 /km, quicker per km than 2980 s over 10 km (4:58 /km).
      expect(find.text('4:40 /km'), findsOneWidget);
      expect(find.text('4:58 /km'), findsOneWidget);
    });

    testWidgets('a distance the run never reached is absent, not greyed out', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // A 4 km run: the 10 km best effort is not missing data, it is not a
      // concept (M34).
      await _pump(tester, runWithBestEfforts(best5k: null, best10k: null));

      expect(find.text('Fastest 1 km'), findsOneWidget);
      expect(find.text('Fastest 5 km'), findsNothing);
      expect(find.text('Fastest 10 km'), findsNothing);
    });

    testWidgets('a run with no best efforts at all drops the whole card', (tester) async {
      // A treadmill run: no track, so no windows — the card would be an
      // empty frame.
      await _pump(tester, runWithBestEfforts(best1k: null, best5k: null, best10k: null));

      expect(find.text('BEST EFFORTS'), findsNothing);
    });

    testWidgets('the record row is marked, the others are not', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pump(
        tester,
        runWithBestEfforts(),
        newRecords: const [CardioPrType.fastest5k],
      );
      await tester.pumpAndSettle();
      // Dismiss the celebration so the card underneath is reachable.
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('record'), findsOneWidget);
    });
  });

  group('record celebration (M36)', () {
    testWidgets('four records produce one dialog with one list', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pump(
        tester,
        _session(
          activityType: 'RUNNING',
          movingSeconds: 3600,
          cardio: const CardioMetrics(
            distanceMeters: 12000,
            best1kSeconds: 250,
            best5kSeconds: 1400,
            best10kSeconds: 2980,
          ),
        ),
        newRecords: const [
          CardioPrType.longestDistance,
          CardioPrType.fastest1k,
          CardioPrType.fastest5k,
          CardioPrType.fastest10k,
        ],
        previousBests: CardioPrBaseline(
          longestDistance: CardioPrBest(value: 11000, at: DateTime(2026, 7, 12)),
          fastest1k: CardioPrBest(value: 260, at: DateTime(2026, 7, 12)),
          fastest5k: CardioPrBest(value: 1476, at: DateTime(2026, 7, 12)),
          fastest10k: CardioPrBest(value: 3000, at: DateTime(2026, 7, 12)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('4 records in one run'), findsOneWidget);
      // One list: every broken record named once, inside that single dialog.
      // Scoped to the dialog — the best-efforts card underneath names the
      // same distances, which is the point of M36's closing line ("a
      // rekordok az összegzés sorain is ott maradnak").
      Finder inDialog(String text) =>
          find.descendant(of: find.byType(AlertDialog), matching: find.text(text));
      expect(inDialog('Fastest 1 km'), findsOneWidget);
      expect(inDialog('Fastest 5 km'), findsOneWidget);
      expect(inDialog('Fastest 10 km'), findsOneWidget);
      expect(inDialog('Longest distance'), findsOneWidget);
    });

    testWidgets('each row names the value it replaced and by how much', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pump(
        tester,
        _session(
          activityType: 'RUNNING',
          movingSeconds: 3600,
          cardio: const CardioMetrics(distanceMeters: 12000, best5kSeconds: 1400),
        ),
        newRecords: const [CardioPrType.fastest5k],
        previousBests: CardioPrBaseline(
          fastest5k: CardioPrBest(value: 1476, at: DateTime(2026, 7, 12)),
        ),
      );
      await tester.pumpAndSettle();

      Finder inDialog(String text) =>
          find.descendant(of: find.byType(AlertDialog), matching: find.text(text));
      expect(inDialog('23:20'), findsOneWidget); // the new record
      expect(find.text('previous: 24:36 · July 12'), findsOneWidget);
      // A best effort improves *downward*; the gain is written as time saved
      // rather than as a negative number to decode.
      expect(find.text('−1:16'), findsOneWidget);
    });

    testWidgets('reopening a past session celebrates nothing', (tester) async {
      await _pump(
        tester,
        _session(
          activityType: 'RUNNING',
          movingSeconds: 3600,
          cardio: const CardioMetrics(distanceMeters: 12000, best5kSeconds: 1400),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a single record uses the singular headline', (tester) async {
      await _pump(
        tester,
        _session(
          activityType: 'RUNNING',
          movingSeconds: 3600,
          cardio: const CardioMetrics(distanceMeters: 12000, best5kSeconds: 1400),
        ),
        newRecords: const [CardioPrType.fastest5k],
      );
      await tester.pumpAndSettle();

      expect(find.text('New record'), findsOneWidget);
    });
  });
}
