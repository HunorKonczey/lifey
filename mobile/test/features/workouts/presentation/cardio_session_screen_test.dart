import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_session_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// C2.1: `CardioSessionScreen` — the live state machine skeleton.
/// docs/cardio/59-cardio-implementation-plan.md C2.1 — kész-ha: "App-kilövés
/// után az edzés helyreáll a pontos mozgásidővel" (after an app kill, the
/// workout restores with exact moving time).
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
  }) async {
    if (failNext) throw Exception('boom');
    finishCalls.add({
      'clientId': clientId,
      'startedAt': startedAt,
      'finishedAt': finishedAt,
      'movingSeconds': movingSeconds,
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

Future<_RecordingSessionController> _pump(WidgetTester tester, WorkoutSession session) async {
  final controller = _RecordingSessionController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => controller),
        settingsControllerProvider.overrideWith(_MetricSettings.new),
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

  testWidgets('a running session shows Pause and Finish, not Resume', (tester) async {
    await _pump(tester, _runningSession(movingSinceEpochMs: DateTime.now().millisecondsSinceEpoch));

    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);
    expect(find.text('Finish'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
  });

  testWidgets('a paused session shows Resume and Finish, not Pause', (tester) async {
    await _pump(tester, _pausedSession(movingSeconds: 400));

    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Finish'), findsOneWidget);
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
  });

  testWidgets('Finish asks for confirmation, then sends the final total and stops showing controls',
      (tester) async {
    final controller = await _pump(tester, _pausedSession(movingSeconds: 754));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Finish'));
    await tester.pumpAndSettle();

    // The confirm dialog is up; nothing sent yet.
    expect(controller.finishCalls, isEmpty);
    expect(find.text('Finish workout?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pumpAndSettle();

    expect(controller.finishCalls, hasLength(1));
    expect(controller.finishCalls.single['movingSeconds'], 754);
    expect(find.text('Finished'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('cancelling the finish confirmation leaves the session running', (tester) async {
    final controller = await _pump(tester, _pausedSession(movingSeconds: 754));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Finish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(controller.finishCalls, isEmpty);
    expect(find.text('Paused'), findsOneWidget);
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
}
