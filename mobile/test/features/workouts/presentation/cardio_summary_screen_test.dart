import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_summary_screen.dart';
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

Future<_RecordingSessionController> _pump(WidgetTester tester, WorkoutSession session) async {
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
        home: CardioSummaryScreen(session: session),
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

void main() {
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
}
