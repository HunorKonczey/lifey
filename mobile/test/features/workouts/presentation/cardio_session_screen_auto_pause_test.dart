import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:lifey/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// C4a.5a — GPS-driven auto-pause, bound to `CardioSessionScreen`.
/// docs/cardio/53-cardio-mobile-plan.md §4.3 — kész-ha: "Ha 15 másodpercig a
/// sebesség < 0,5 m/s (és van GPS-jel), automatikus szünet; mozgásra
/// automatikus folytatás." `auto_pause_detector_test.dart` covers the
/// detector's own gating logic in isolation; this file is the screen-level
/// wiring: the M08/M09 card, the position-subscription lifetime during an
/// auto-pause, and the on/off preference actually taking effect.

class _RecordingSessionController extends WorkoutSessionController {
  final pauseCalls = <Map<String, Object?>>[];
  final resumeCalls = <Map<String, Object?>>[];

  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);

  @override
  Future<void> pauseCardioSession(String clientId,
      {required DateTime startedAt, required int movingSeconds}) async {
    pauseCalls.add({'clientId': clientId});
  }

  @override
  Future<void> resumeCardioSession(String clientId,
      {required DateTime startedAt, required DateTime resumedAt}) async {
    resumeCalls.add({'clientId': clientId});
  }

  @override
  Future<void> finishCardioSession(String clientId,
      {required DateTime startedAt,
      required DateTime finishedAt,
      required int movingSeconds,
      Value<CardioMetrics?> cardio = const Value.absent(),
      Value<List<CardioSplit>> splits = const Value.absent()}) async {}

  @override
  Future<void> updateLiveCardioMetrics(String clientId,
      {required DateTime startedAt, required CardioMetrics cardio}) async {}
}

class _MetricSettings extends SettingsController {
  @override
  Stream<UserSettings> build() => Stream.value(const UserSettings.defaults());
}

WorkoutSession _runningSession() {
  final since = DateTime.now().subtract(const Duration(minutes: 5));
  return WorkoutSession(
    clientId: 'live-1',
    exercises: const [],
    sets: const [],
    startedAt: since,
    sessionKind: 'CARDIO',
    activityType: 'RUNNING',
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

AppDatabase _testDatabase() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// `AutoPauseDetector` never reads `recordedAt` (unlike `track_filter.dart`'s
/// speed gate, which computes elapsed time between fixes) — a fixed
/// timestamp is fine for every fix in this file.
LocationFix _fix({required double lat, required double speed}) => LocationFix(
      latitude: lat,
      longitude: 19.05,
      speed: speed,
      recordedAt: DateTime.utc(2026, 8, 13),
    );


/// A fix that actually *moves*, with an advancing timestamp — unlike [_fix],
/// which is only ever fed to the auto-pause detector. `track_filter.dart`
/// rejects a fix that shares its predecessor's timestamp (it can't derive a
/// speed from a zero interval), so anything meant to grow the live distance
/// has to carry real time.
///
/// ~11.1 m north of fix `n - 1`, 3 s apart. [speed] is what the auto-pause
/// detector reads, and it is deliberately independent of that displacement:
/// a GPS drifting 11 m while its owner stands at a light reports a low speed,
/// which is exactly the case C6.6 has to get right.
LocationFix _movingFix(int n, {required double speed}) => LocationFix(
      latitude: 47.5 + n * 0.0001,
      longitude: 19.05,
      speed: speed,
      recordedAt: DateTime.utc(2026, 8, 13, 7).add(Duration(seconds: n * 3)),
    );

/// Records every `HapticFeedback` platform call — how the kilometre cue is
/// observed from a widget test (C6.6). The channel also carries
/// `SystemSound.play`, so this doubles as proof that a silent profile stays
/// silent.
List<String> _recordPlatformCalls(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate' || call.method == 'SystemSound.play') {
        calls.add(call.method);
      }
      return null;
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

/// Emits [count] moving fixes starting at index [from].
Future<void> _emitMoving(
  WidgetTester tester,
  LocationServiceStub location, {
  required int from,
  required int count,
  required double speed,
}) async {
  for (var n = from; n < from + count; n++) {
    location.emitFix(_movingFix(n, speed: speed));
    await tester.pump();
  }
}

Future<
    ({
      _RecordingSessionController controller,
      LocationServiceStub location,
    })> _pump(WidgetTester tester) async {
  final controller = _RecordingSessionController();
  final location = _grantedLocationStub();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workoutSessionControllerProvider.overrideWith(() => controller),
        settingsControllerProvider.overrideWith(_MetricSettings.new),
        locationServiceProvider.overrideWithValue(location),
        appDatabaseProvider.overrideWithValue(_testDatabase()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CardioSessionScreen(session: _runningSession()),
      ),
    ),
  );
  await tester.pump(); // initState's async seeds (track points, auto-pause pref)
  await tester.pump();
  return (controller: controller, location: location);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('15 s of sub-0.5 m/s speed triggers an automatic pause (M09 card)', (tester) async {
    final ctx = await _pump(tester);
    ctx.location.emitFix(_fix(lat: 47.5, speed: 0.1));

    await tester.pump(const Duration(seconds: 15));

    expect(ctx.controller.pauseCalls, hasLength(1));
    expect(find.text('Automatic pause'), findsOneWidget);
  });

  testWidgets('a fast fix before 15 s cancels the countdown — stays running', (tester) async {
    final ctx = await _pump(tester);
    ctx.location.emitFix(_fix(lat: 47.5, speed: 0.1));
    await tester.pump(const Duration(seconds: 10));
    ctx.location.emitFix(_fix(lat: 47.5, speed: 3.0));

    await tester.pump(const Duration(seconds: 10)); // past the original 15 s deadline

    expect(ctx.controller.pauseCalls, isEmpty);
    expect(find.text('Automatic pause'), findsNothing);
  });

  testWidgets('once auto-paused, a fast fix triggers an automatic resume', (tester) async {
    final ctx = await _pump(tester);
    ctx.location.emitFix(_fix(lat: 47.5, speed: 0.1));
    await tester.pump(const Duration(seconds: 15));
    expect(ctx.controller.pauseCalls, hasLength(1));

    ctx.location.emitFix(_fix(lat: 47.5, speed: 3.0));
    await tester.pump();

    expect(ctx.controller.resumeCalls, hasLength(1));
    expect(find.text('Automatic pause'), findsNothing);
  });

  testWidgets(
      'no track point is recorded while auto-paused, even though the subscription is still '
      'listening for motion', (tester) async {
    final ctx = await _pump(tester);
    ctx.location.emitFix(_fix(lat: 47.5, speed: 0.1));
    await tester.pump(const Duration(seconds: 15));
    expect(ctx.controller.pauseCalls, hasLength(1));

    // A fix that arrives *during* the auto-pause — must not be recorded.
    ctx.location.emitFix(_fix(lat: 47.501, speed: 0.1));
    await tester.pump();

    // Only the very first (pre-pause) fix ever got a chance to be written —
    // and that one was a `speed: 0.1` fix too, immediately slow, so even it
    // never advanced the distance; the count that matters here is that nothing
    // *additional* landed while paused.
    final points = await CardioTrackPointRepository(
      ProviderScope.containerOf(tester.element(find.byType(CardioSessionScreen)))
          .read(appDatabaseProvider),
    ).pointsForSession('live-1');
    expect(points, hasLength(1)); // just the one fix recorded before the pause fired
  });

  testWidgets('manually pausing stops listening entirely — a fast fix afterward does not '
      'auto-resume', (tester) async {
    final ctx = await _pump(tester);

    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();

    ctx.location.emitFix(_fix(lat: 47.5, speed: 3.0));
    await tester.pump();

    expect(ctx.controller.resumeCalls, isEmpty); // never delivered — the sub was cancelled
    expect(find.text('Paused'), findsOneWidget); // the manual pause card, not "Automatic pause"
  });

  testWidgets('auto-pause disabled in preferences: sustained slow speed never pauses',
      (tester) async {
    SharedPreferences.setMockInitialValues({'cardio.autoPauseEnabled': false});
    final ctx = await _pump(tester);
    ctx.location.emitFix(_fix(lat: 47.5, speed: 0.1));

    await tester.pump(const Duration(seconds: 15));

    expect(ctx.controller.pauseCalls, isEmpty);
  });

  testWidgets('toggling auto-pause off via the sheet, then dismissing it, disables detection',
      (tester) async {
    final ctx = await _pump(tester);

    await tester.tap(find.byTooltip('Auto-pause settings'));
    await tester.pumpAndSettle();
    // The sheet holds three switches since C6.6 — auto-pause is the first.
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pump();
    // Dismiss the sheet by dragging it down / tapping the barrier — simplest
    // reliable way in a widget test is popping the root navigator directly.
    Navigator.of(tester.element(find.byType(SwitchListTile).first), rootNavigator: true).pop();
    await tester.pumpAndSettle();

    ctx.location.emitFix(_fix(lat: 47.5, speed: 0.1));
    await tester.pump(const Duration(seconds: 15));

    expect(ctx.controller.pauseCalls, isEmpty);
  });

  // -- Kilometre cue (C6.6, docs/cardio/61 §2 M35) -------------------------

  group('kilometre cue', () {
    testWidgets('crossing a kilometre while running fires the cue', (tester) async {
      final ctx = await _pump(tester);
      final calls = _recordPlatformCalls(tester);

      // ~11.1 m per fix: 89 fixes is just under a kilometre, 95 is past it.
      await _emitMoving(tester, ctx.location, from: 0, count: 89, speed: 5);
      expect(calls, isEmpty, reason: 'the first kilometre is not finished yet');

      await _emitMoving(tester, ctx.location, from: 89, count: 6, speed: 5);
      // Two short taps (M35), the second one 140 ms later.
      await tester.pump(const Duration(milliseconds: 200));

      expect(calls.where((c) => c == 'HapticFeedback.vibrate'), hasLength(2));
      // Sound is off by default — the cue is silent unless asked for.
      expect(calls, isNot(contains('SystemSound.play')));
    });

    testWidgets('the same kilometre never cues twice', (tester) async {
      final ctx = await _pump(tester);
      final calls = _recordPlatformCalls(tester);

      await _emitMoving(tester, ctx.location, from: 0, count: 95, speed: 5);
      await tester.pump(const Duration(milliseconds: 200));
      final afterFirstKm = calls.length;

      await _emitMoving(tester, ctx.location, from: 95, count: 20, speed: 5);
      await tester.pump(const Duration(milliseconds: 200));

      expect(calls, hasLength(afterFirstKm), reason: 'still inside the second kilometre');
    });

    testWidgets('an auto-paused session never cues, however far its fixes drift',
        (tester) async {
      // The kész-ha: "auto-pause alatt nem üt". A phone left on a bench keeps
      // producing fixes, and a drifting GPS can wander a long way — none of
      // it is running, so none of it may cue.
      final ctx = await _pump(tester);
      final calls = _recordPlatformCalls(tester);

      // ~500 m of real running first, so the cue is genuinely close.
      await _emitMoving(tester, ctx.location, from: 0, count: 45, speed: 5);
      expect(calls, isEmpty);

      // Slow down and stay slow: 15 s of sub-threshold speed auto-pauses.
      await _emitMoving(tester, ctx.location, from: 45, count: 3, speed: 0.1);
      await tester.pump(const Duration(seconds: 15));
      expect(ctx.controller.pauseCalls, hasLength(1), reason: 'auto-paused');

      // Now drift far past where the first kilometre would have been. If a
      // paused session counted these, the cue would fire.
      await _emitMoving(tester, ctx.location, from: 48, count: 60, speed: 0.1);
      await tester.pump(const Duration(milliseconds: 200));

      expect(calls, isEmpty);
    });

    testWidgets('with both cue switches off, crossing a kilometre stays silent',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'cardio.kmCueVibration': false,
        'cardio.kmCueSound': false,
      });
      final ctx = await _pump(tester);
      final calls = _recordPlatformCalls(tester);

      await _emitMoving(tester, ctx.location, from: 0, count: 95, speed: 5);
      await tester.pump(const Duration(milliseconds: 200));

      expect(calls, isEmpty);
    });

    testWidgets('with sound on, the kilometre also plays a tone', (tester) async {
      SharedPreferences.setMockInitialValues({
        'cardio.kmCueVibration': false,
        'cardio.kmCueSound': true,
      });
      final ctx = await _pump(tester);
      final calls = _recordPlatformCalls(tester);

      await _emitMoving(tester, ctx.location, from: 0, count: 95, speed: 5);
      await tester.pump(const Duration(milliseconds: 200));

      expect(calls, contains('SystemSound.play'));
      expect(calls, isNot(contains('HapticFeedback.vibrate')));
    });
  });
}
