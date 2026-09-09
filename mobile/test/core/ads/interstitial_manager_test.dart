import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lifey/core/ads/interstitial_ad_loader.dart';
import 'package:lifey/core/ads/interstitial_manager.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/features/workouts/application/workout_session_controller.dart';
import 'package:lifey/features/workouts/domain/workout_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers Prompt 10's remaining verify items — the two the pure
/// `isInterstitialEligible` (`is_interstitial_eligible_test.dart`) can't
/// reach on its own: a cold start within 4h of the last interstitial shows
/// nothing (the persisted limit surviving a process restart, 63 §8.8), and
/// an active workout suppresses it end-to-end through the real provider it
/// reads.

class _FakeLoadedInterstitialAd implements LoadedInterstitialAd {
  int showCallCount = 0;

  @override
  Future<void> show() async {
    showCallCount++;
  }
}

class _FakeInterstitialAdLoader implements InterstitialAdLoader {
  int loadCallCount = 0;
  bool returnsNull = false;
  final loaded = _FakeLoadedInterstitialAd();

  @override
  Future<LoadedInterstitialAd?> load(String adUnitId, AdRequest request) async {
    loadCallCount++;
    return returnsNull ? null : loaded;
  }
}

class _EmptyWorkoutSessionController extends WorkoutSessionController {
  @override
  Stream<List<WorkoutSession>> build() => Stream.value(const []);
}

class _ActiveWorkoutSessionController extends WorkoutSessionController {
  @override
  Stream<List<WorkoutSession>> build() => Stream.value([
        WorkoutSession(
          clientId: 'active',
          exercises: const [],
          sets: const [],
          startedAt: DateTime.now(),
        ),
      ]);
}

/// Builds a container whose [interstitialManagerProvider] is the one under
/// test — [now] anchors both its constructor-time `_foregroundedAt` and (via
/// the same fixed clock) every `maybeShow` call read against it, unless the
/// test advances [nowRef] itself.
({ProviderContainer container, InterstitialManager manager}) _build({
  required InterstitialAdLoader loader,
  required List<DateTime> nowRef,
  bool adsEnabled = true,
  WorkoutSessionController Function()? sessionController,
}) {
  final container = ProviderContainer(overrides: [
    adsEnabledProvider.overrideWithValue(adsEnabled),
    workoutSessionControllerProvider
        .overrideWith(sessionController ?? _EmptyWorkoutSessionController.new),
    interstitialManagerProvider
        .overrideWith((ref) => InterstitialManager(ref, loader: loader, now: () => nowRef[0])),
  ]);
  addTearDown(container.dispose);
  // `container.read` alone doesn't establish a persistent listener, so
  // `InterstitialManager._hasActiveSession`'s own `ref.read` can see the
  // stream's first emission not yet landed — same Riverpod gotcha
  // documented in `ads_service_provider_test.dart`'s `_keepAlive`.
  container.listen(workoutSessionControllerProvider, (_, __) {});
  return (container: container, manager: container.read(interstitialManagerProvider));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('eligible: loads, shows, and persists the shown time', (tester) async {
    final loader = _FakeInterstitialAdLoader();
    final nowRef = [DateTime(2026, 9, 1, 12, 0, 0)];
    final built = _build(loader: loader, nowRef: nowRef);
    // Past the manager's own construction-time foreground anchor.
    nowRef[0] = nowRef[0].add(const Duration(minutes: 5));

    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    await built.manager.maybeShow(context, InterstitialReason.workoutSaved);

    expect(loader.loadCallCount, 1);
    expect(loader.loaded.showCallCount, 1);
  });

  testWidgets('an active workout or cardio session suppresses it', (tester) async {
    final loader = _FakeInterstitialAdLoader();
    final nowRef = [DateTime(2026, 9, 1, 12, 0, 0)];
    final built = _build(
      loader: loader,
      nowRef: nowRef,
      sessionController: _ActiveWorkoutSessionController.new,
    );
    nowRef[0] = nowRef[0].add(const Duration(minutes: 5));

    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    await built.manager.maybeShow(context, InterstitialReason.mealLogged);

    expect(loader.loadCallCount, 0);
  });

  testWidgets(
      'a cold start within 4h of the last interstitial shows nothing (63 §8.8: the rate '
      'limit is persisted, not in-memory)', (tester) async {
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));

    final firstShownAt = DateTime(2026, 9, 1, 8, 0, 0);
    final firstNowRef = [firstShownAt];
    final firstLoader = _FakeInterstitialAdLoader();
    final first = _build(loader: firstLoader, nowRef: firstNowRef);
    firstNowRef[0] = firstShownAt.add(const Duration(minutes: 5));
    await first.manager.maybeShow(context, InterstitialReason.workoutSaved);
    expect(firstLoader.loaded.showCallCount, 1);

    // A brand new InterstitialManager over a brand new ProviderContainer —
    // nothing in-memory carries over (_shownThisSession is a fresh `false`,
    // and this instance's own foreground timer is fresh too) — models the
    // app process having been killed and relaunched. Only shared_preferences
    // survives that, exactly what's under test here.
    final coldStartAt = firstShownAt.add(const Duration(hours: 2));
    final secondNowRef = [coldStartAt];
    final secondLoader = _FakeInterstitialAdLoader();
    final second = _build(loader: secondLoader, nowRef: secondNowRef);
    // Also past its own 60s foreground gate, so the persisted rate limit is
    // the only thing left that could be suppressing it.
    secondNowRef[0] = coldStartAt.add(const Duration(minutes: 5));

    await second.manager.maybeShow(context, InterstitialReason.workoutSaved);

    expect(secondLoader.loadCallCount, 0);
  });

  testWidgets(
      'not already shown this app session: a second call in the same process shows nothing',
      (tester) async {
    final loader = _FakeInterstitialAdLoader();
    final nowRef = [DateTime(2026, 9, 1, 12, 0, 0)];
    final built = _build(loader: loader, nowRef: nowRef);
    nowRef[0] = nowRef[0].add(const Duration(minutes: 5));

    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));

    await built.manager.maybeShow(context, InterstitialReason.mealLogged);
    expect(loader.loadCallCount, 1);

    await built.manager.maybeShow(context, InterstitialReason.mealLogged);
    expect(loader.loadCallCount, 1);
  });

  testWidgets(
      'the foreground timer resets on every fresh resume, so a cold start is never eligible',
      (tester) async {
    final loader = _FakeInterstitialAdLoader();
    final nowRef = [DateTime(2026, 9, 1, 12, 0, 0)];
    final built = _build(loader: loader, nowRef: nowRef);

    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));

    // Constructed "now" — a cold start's very first frame.
    await built.manager.maybeShow(context, InterstitialReason.mealLogged);
    expect(loader.loadCallCount, 0);

    // The app is backgrounded, then resumed again 61s after construction —
    // long enough that the *original* foreground anchor would have cleared
    // the 60s gate, but the resume itself restarts the timer, so calling
    // right after the resume is still too soon.
    nowRef[0] = nowRef[0].add(const Duration(seconds: 61));
    built.manager.didChangeAppLifecycleState(AppLifecycleState.paused);
    built.manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await built.manager.maybeShow(context, InterstitialReason.mealLogged);
    expect(loader.loadCallCount, 0);
  });

  testWidgets('markOpenedFromPush suppresses it, cleared by the next resume', (tester) async {
    final loader = _FakeInterstitialAdLoader();
    final nowRef = [DateTime(2026, 9, 1, 12, 0, 0)];
    final built = _build(loader: loader, nowRef: nowRef);
    nowRef[0] = nowRef[0].add(const Duration(minutes: 5));

    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));

    built.manager.markOpenedFromPush();
    await built.manager.maybeShow(context, InterstitialReason.mealLogged);
    expect(loader.loadCallCount, 0);

    // The resume clears the flag but also restarts the foreground timer —
    // advance past its own 60s gate too, so this second call is testing the
    // push flag specifically, not accidentally blocked by that instead.
    built.manager.didChangeAppLifecycleState(AppLifecycleState.resumed);
    nowRef[0] = nowRef[0].add(const Duration(seconds: 61));
    await built.manager.maybeShow(context, InterstitialReason.mealLogged);
    expect(loader.loadCallCount, 1);
  });

  testWidgets('a failed load (returns null) shows nothing and does not mark this session as shown',
      (tester) async {
    final loader = _FakeInterstitialAdLoader()..returnsNull = true;
    final nowRef = [DateTime(2026, 9, 1, 12, 0, 0)];
    final built = _build(loader: loader, nowRef: nowRef);
    nowRef[0] = nowRef[0].add(const Duration(minutes: 5));

    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));

    await built.manager.maybeShow(context, InterstitialReason.mealLogged);
    expect(loader.loadCallCount, 1);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ads.lastInterstitialShownAt'), isNull);
  });
}
