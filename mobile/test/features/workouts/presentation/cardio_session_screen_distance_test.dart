import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_session_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// C2.2: the DISTANCE family layout on `CardioSessionScreen` — the
/// dominant/secondary switch and the manual distance edit that stands in
/// for GPS until C4a. docs/cardio/59-cardio-implementation-plan.md C2.2 —
/// kész-ha: "A domináns szám a [57 §2] szabálya szerint vált; nincs
/// „0,00 km” nagy helyen."

class _RecordingSessionController extends WorkoutSessionController {
  final updateLiveCardioMetricsCalls = <Map<String, Object?>>[];

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
          required int movingSeconds}) async {}

  @override
  Future<void> updateLiveCardioMetrics(
    String clientId, {
    required DateTime startedAt,
    required CardioMetrics cardio,
  }) async {
    updateLiveCardioMetricsCalls.add({'clientId': clientId, 'cardio': cardio});
  }
}

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

class _ImperialSettings extends SettingsController {
  @override
  Stream<UserSettings> build() =>
      Stream.value(const UserSettings.defaults().copyWith(unitSystem: UnitSystem.imperial));
}

WorkoutSession _distanceSession({
  double? distanceMeters,
  int movingSeconds = 0,
  int? movingSinceEpochMs,
  String activityType = 'RUNNING',
}) {
  return WorkoutSession(
    clientId: 'live-1',
    exercises: const [],
    sets: const [],
    startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    sessionKind: 'CARDIO',
    activityType: activityType,
    movingSeconds: movingSeconds,
    movingSinceEpochMs: movingSinceEpochMs,
    cardio: distanceMeters == null ? null : CardioMetrics(distanceMeters: distanceMeters),
  );
}

Future<_RecordingSessionController> _pump(
  WidgetTester tester,
  WorkoutSession session, {
  bool imperial = false,
}) async {
  final controller = _RecordingSessionController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => controller),
        settingsControllerProvider
            .overrideWith(imperial ? _ImperialSettings.new : _MetricSettings.new),
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
  testWidgets('no distance recorded: moving time is dominant, distance shows the placeholder',
      (tester) async {
    await _pump(tester, _distanceSession(movingSeconds: 754));

    expect(tester.takeException(), isNull);
    expect(find.text('MOVING TIME'), findsOneWidget);
    expect(find.text('12:34'), findsOneWidget);
    expect(find.text('DISTANCE'), findsOneWidget);
    // The never-show-a-big-zero guarantee: no "0.00 km" anywhere, dominant or not.
    expect(find.textContaining('0.00 km'), findsNothing);
    expect(find.text('PACE'), findsOneWidget);
    expect(find.text('HEART RATE'), findsOneWidget);
  });

  testWidgets('a recorded distance becomes dominant; moving time and pace move to secondary',
      (tester) async {
    await _pump(
      tester,
      _distanceSession(distanceMeters: 5000, movingSeconds: 1500), // 25:00 -> 5:00 /km
    );

    expect(find.text('DISTANCE'), findsOneWidget);
    expect(find.text('5.00 km'), findsOneWidget);
    expect(find.text('MOVING TIME'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('PACE'), findsOneWidget);
    expect(find.text('5:00 /km'), findsOneWidget);
  });

  testWidgets('a zero distance is treated the same as no distance (still falls back)',
      (tester) async {
    await _pump(tester, _distanceSession(distanceMeters: 0, movingSeconds: 60));

    expect(find.text('MOVING TIME'), findsOneWidget);
    expect(find.textContaining('km'), findsNothing);
  });

  testWidgets('tapping the distance placeholder opens the edit dialog and saves in km',
      (tester) async {
    final controller = await _pump(tester, _distanceSession(movingSeconds: 60));

    await tester.tap(find.text('DISTANCE'));
    await tester.pumpAndSettle();
    expect(find.text('Update distance'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '4.20');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(controller.updateLiveCardioMetricsCalls, hasLength(1));
    final cardio = controller.updateLiveCardioMetricsCalls.single['cardio'] as CardioMetrics;
    expect(cardio.distanceMeters, closeTo(4200, 0.01));
    expect(cardio.distanceSource, 'MANUAL');
    // The screen adopts the new value immediately without waiting for a re-pump from outside.
    expect(find.text('4.20 km'), findsOneWidget);
  });

  testWidgets('tapping the dominant distance number also opens the edit dialog', (tester) async {
    await _pump(tester, _distanceSession(distanceMeters: 5000, movingSeconds: 1500));

    await tester.tap(find.text('5.00 km'));
    await tester.pumpAndSettle();

    expect(find.text('Update distance'), findsOneWidget);
  });

  testWidgets('cancelling the edit dialog leaves the distance unchanged', (tester) async {
    final controller = await _pump(tester, _distanceSession(movingSeconds: 60));

    await tester.tap(find.text('DISTANCE'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4.20');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(controller.updateLiveCardioMetricsCalls, isEmpty);
    expect(find.text('MOVING TIME'), findsOneWidget);
  });

  testWidgets('respects the imperial unit system: entry in miles converts to meters',
      (tester) async {
    final controller = await _pump(tester, _distanceSession(movingSeconds: 60), imperial: true);

    await tester.tap(find.text('DISTANCE'));
    await tester.pumpAndSettle();
    expect(find.text('mi'), findsWidgets);

    await tester.enterText(find.byType(TextField), '1.00');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final cardio = controller.updateLiveCardioMetricsCalls.single['cardio'] as CardioMetrics;
    expect(cardio.distanceMeters, closeTo(1609.344, 0.01));
  });

  // A "GAME still shows the generic placeholder" cross-family check used to
  // live here — obsolete since C2.4 (GAME now has its own layout too; see
  // cardio_session_screen_game_test.dart). No family uses the C2.1 generic
  // body anymore, so there's nothing left to assert against from this file.
}
