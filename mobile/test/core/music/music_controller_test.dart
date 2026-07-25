import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/music/music_controller.dart';
import 'package:lifey/core/music/music_provider_id.dart';
import 'package:lifey/core/music/music_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('starts as notConfigured before activate() is ever called', () {
    final state = container.read(musicControllerProvider);
    expect(state.status, MusicConnectionStatus.notConfigured);
    expect(state.provider, isNull);
  });

  test('activate() with no provider chosen yet stays notConfigured', () async {
    await container.read(musicControllerProvider.notifier).activate();

    final state = container.read(musicControllerProvider);
    expect(state.status, MusicConnectionStatus.notConfigured);
  });

  test('selectProvider() after activate() moves to noActiveSession with that provider', () async {
    final notifier = container.read(musicControllerProvider.notifier);
    await notifier.activate();
    await notifier.selectProvider(MusicProviderId.spotify);

    final state = container.read(musicControllerProvider);
    expect(state.status, MusicConnectionStatus.noActiveSession);
    expect(state.provider, MusicProviderId.spotify);
  });

  test('a re-entrant screen sees the previously chosen provider on activate()', () async {
    final notifier = container.read(musicControllerProvider.notifier);
    await notifier.activate();
    await notifier.selectProvider(MusicProviderId.appleMusic);
    await notifier.deactivate();

    // Simulates a fresh LogSessionScreen instance re-activating for the same
    // running session (docs/music/46-workout-music-controls-plan.md §3.3) —
    // the device-local choice survives the deactivate/activate cycle.
    await notifier.activate();

    final state = container.read(musicControllerProvider);
    expect(state.status, MusicConnectionStatus.noActiveSession);
    expect(state.provider, MusicProviderId.appleMusic);
  });

  test('deactivate() resets to initial and stops reacting to further service changes', () async {
    final notifier = container.read(musicControllerProvider.notifier);
    await notifier.activate();
    await notifier.selectProvider(MusicProviderId.spotify);
    await notifier.deactivate();

    expect(container.read(musicControllerProvider), same(MusicSessionState.initial));

    // The controller unsubscribed on deactivate() — a further service-level
    // change must not leak back into the controller's state.
    await notifier.selectProvider(MusicProviderId.youtubeMusic);
    expect(container.read(musicControllerProvider).status, MusicConnectionStatus.notConfigured);
  });
}
