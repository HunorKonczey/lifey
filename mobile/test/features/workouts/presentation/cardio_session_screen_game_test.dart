import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_session_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

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

  @override
  Future<void> finishCardioSession(String clientId,
      {required DateTime startedAt,
      required DateTime finishedAt,
      required int movingSeconds,
      Value<CardioMetrics?> cardio = const Value.absent(),
      Value<List<CardioSplit>> splits = const Value.absent()}) async {}
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

  testWidgets('no score/box-score counter renders — Q-D2 is deferred to C9, not resolved here',
      (tester) async {
    await _pump(tester, _liveOnCourtSession());

    expect(find.byIcon(Icons.scoreboard), findsNothing);
    expect(find.text('SCORE'), findsNothing);
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
}
