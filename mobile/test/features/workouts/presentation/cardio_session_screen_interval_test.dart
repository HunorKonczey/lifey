import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/local_db/app_database.dart';
import 'package:lifey/core/local_db/database_provider.dart';
import 'package:lifey/core/sync/outbox_writer.dart';
import 'package:lifey/features/settings/application/settings_controller.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/data/cardio_interval_plan_repository.dart';
import 'package:lifey/features/workouts/domain/cardio_interval_plan.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:lifey/features/workouts/presentation/cardio_session_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// docs/cardio/60 C7.5 — the player on the live MACHINE screen (M38). The
/// section maths is covered by `interval_player_controller_test.dart`; what
/// this file checks is the part only the screen can answer: the block is
/// there with a plan, the screen is untouched without one, the section clock
/// visibly freezes with the pause, and finishing hands the executed sections
/// to the repository as INTERVAL splits.

class _RecordingSessionController extends WorkoutSessionController {
  final finishCalls = <List<CardioSplit>>[];

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
    finishCalls.add(splits.present ? splits.value : const []);
  }

  @override
  Future<void> updateLiveCardioMetrics(String clientId,
      {required DateTime startedAt, required CardioMetrics cardio}) async {}
}

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

/// 5:00 easy · 4× (4:00 hard + 3:00 easy) · 5:00 easy.
const _plan = CardioIntervalPlan(
  clientId: 'plan-1',
  name: 'Tuesday 4x4',
  steps: [
    IntervalStep.section(
        name: 'Warm-up', intensity: IntervalIntensity.easy, durationSeconds: 300),
    IntervalStep.block(repeatCount: 4, children: [
      IntervalStep.section(
          name: 'Hard', intensity: IntervalIntensity.hard, durationSeconds: 240),
      IntervalStep.section(
          name: 'Rest', intensity: IntervalIntensity.easy, durationSeconds: 180),
    ]),
    IntervalStep.section(
        name: 'Cool-down', intensity: IntervalIntensity.easy, durationSeconds: 300),
  ],
);

class _StubPlanRepository extends CardioIntervalPlanRepository {
  _StubPlanRepository(super.db, super.outbox);

  @override
  Future<CardioIntervalPlan?> findByClientId(String clientId) async =>
      clientId == 'plan-1' ? _plan : null;
}

/// A paused ride by default: with no `movingSinceEpochMs`, moving time is
/// frozen at [movingSeconds], which keeps every assertion below exact rather
/// than racing the wall clock. [running] is for the cases that need the
/// running control row (the skip circle lives there).
WorkoutSession _bikeSession({int movingSeconds = 0, bool running = false}) {
  return WorkoutSession(
    clientId: 'ride-1',
    exercises: const [],
    sets: const [],
    startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
    sessionKind: 'CARDIO',
    activityType: 'INDOOR_BIKE',
    movingSeconds: movingSeconds,
    movingSinceEpochMs: running ? DateTime.now().millisecondsSinceEpoch : null,
  );
}

Future<_RecordingSessionController> _pump(
  WidgetTester tester,
  WorkoutSession session, {
  String? planClientId,
}) async {
  final controller = _RecordingSessionController();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // See cardio_session_screen_machine_test.dart's own comment on this
        // override — InterstitialManager (67 Prompt 10) needs it here too.
        adsEnabledProvider.overrideWithValue(false),
        workoutSessionControllerProvider.overrideWith(() => controller),
        settingsControllerProvider.overrideWith(_MetricSettings.new),
        appDatabaseProvider.overrideWithValue(db),
        cardioIntervalPlanRepositoryProvider.overrideWith(
          (ref) => _StubPlanRepository(db, ref.watch(outboxWriterProvider)),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CardioSessionScreen(session: session, intervalPlanClientId: planClientId),
      ),
    ),
  );
  // Two pumps: the plan is loaded asynchronously, exactly as it is in the app.
  await tester.pump();
  await tester.pump();
  return controller;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('without a plan the screen is the M05 it has always been', (tester) async {
    await _pump(tester, _bikeSession(movingSeconds: 754));

    expect(tester.takeException(), isNull);
    // The player leaves no trace: no counter, no countdown, no skip circle.
    expect(find.textContaining('SECTION'), findsNothing);
    expect(find.byKey(const Key('intervalSkipCircle')), findsNothing);
    // ...and the M05 furniture is untouched, resistance stepper included.
    expect(find.text('MOVING TIME'), findsOneWidget);
    expect(find.text('12:34'), findsOneWidget);
    expect(find.text('RESISTANCE'), findsOneWidget);
  });

  testWidgets('with a plan the player shows the section, the countdown and what is next',
      (tester) async {
    await _pump(tester, _bikeSession(movingSeconds: 60), planClientId: 'plan-1');

    expect(find.text('SECTION 1/10'), findsOneWidget);
    expect(find.text('EASY'), findsOneWidget);
    expect(find.text('4:00'), findsOneWidget); // 5:00 section, 60 s in
    expect(find.text('to go'), findsOneWidget);
    expect(find.text('Next: 4:00 hard'), findsOneWidget);
    // The resistance stepper still sits where M05 put it.
    expect(find.text('RESISTANCE'), findsOneWidget);
  });

  testWidgets('the moving time shrinks to 82 px while a plan is playing', (tester) async {
    await _pump(tester, _bikeSession(movingSeconds: 60), planClientId: 'plan-1');

    // The single size change M38 allows itself against M05.
    expect(_dominantFontSize(tester, '1:00'), 82);
  });

  testWidgets('the moving time keeps its 96 px without a plan', (tester) async {
    await _pump(tester, _bikeSession(movingSeconds: 60));

    expect(_dominantFontSize(tester, '1:00'), 96);
  });

  testWidgets('the skip circle replaces the trailing circle and steps the section',
      (tester) async {
    await _pump(
      tester,
      _bikeSession(movingSeconds: 60, running: true),
      planClientId: 'plan-1',
    );

    expect(find.byKey(const Key('intervalSkipCircle')), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.byKey(const Key('intervalSkipCircle')));
    await tester.pump();

    // The warm-up ends where the skip happened; the hard section starts there.
    expect(find.text('SECTION 2/10'), findsOneWidget);
    expect(find.text('HARD'), findsOneWidget);
  });

  testWidgets('a paused ride freezes the section and says so', (tester) async {
    // movingSinceEpochMs null = not currently accruing, which is exactly what
    // a paused session looks like.
    await _pump(tester, _bikeSession(movingSeconds: 60), planClientId: 'plan-1');

    expect(find.text('SECTION 1/10'), findsOneWidget);
    expect(find.text('paused'), findsOneWidget);
    expect(
      find.textContaining('The section clock stops with the pause'),
      findsOneWidget,
    );

    // A second of wall-clock time passes; a paused ride's section must not move.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('4:00'), findsOneWidget);
  });

  testWidgets('finishing hands the executed sections over as INTERVAL splits',
      (tester) async {
    final controller = await _pump(
      tester,
      _bikeSession(movingSeconds: 400),
      planClientId: 'plan-1',
    );

    await _slideToFinish(tester);

    expect(controller.finishCalls, hasLength(1));
    final splits = controller.finishCalls.single;
    // The finished warm-up (300 s) plus the hard section the ride ended in,
    // cut off at the 100 s it actually got.
    expect(splits, hasLength(2));
    expect(splits.map((s) => s.splitType), everyElement(CardioSplitType.interval));
    expect(splits.map((s) => s.durationSeconds), [300, 100]);
    expect(splits.map((s) => s.intensity),
        [IntervalIntensity.easy, IntervalIntensity.hard]);
    expect(splits.map((s) => s.distanceMeters), everyElement(isNull));
    // They add up to the moving time — no section is invented and none is lost.
    expect(splits.fold<int>(0, (sum, s) => sum + s.durationSeconds), 400);
  });

  testWidgets('a ride with no plan finishes with no splits at all', (tester) async {
    final controller = await _pump(tester, _bikeSession(movingSeconds: 400));

    await _slideToFinish(tester);

    expect(controller.finishCalls.single, isEmpty);
  });
}

double _dominantFontSize(WidgetTester tester, String value) {
  final text = tester.widgetList<Text>(find.byType(Text)).firstWhere(
        (t) => t.textSpan?.toPlainText() == value,
      );
  final span = text.textSpan! as TextSpan;
  return (span.children!.first as TextSpan).style!.fontSize!;
}

Future<void> _slideToFinish(WidgetTester tester) async {
  final bar = find.byKey(const Key('slideToFinishBar'));
  await tester.drag(bar, const Offset(400, 0));
  await tester.pumpAndSettle();
}
