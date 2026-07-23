import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'music_preferences.dart';
import 'music_provider_id.dart';
import 'music_service.dart';
import 'music_service_android.dart';

/// The UI's single entry point into the music-control feature — a thin
/// pass-through Notifier over whichever `MusicService` is wired up, mirroring
/// how `LogSessionScreen` already drives `WatchWorkoutService` directly.
/// Kept as its own layer (rather than widgets reading `musicServiceProvider`
/// directly) so `activate`/`deactivate` can own the state-stream subscription
/// exactly once, regardless of how many widgets watch [state]
/// (docs/music/46-workout-music-controls-plan.md §3.2).
class MusicController extends Notifier<MusicSessionState> {
  MusicService get _service => ref.read(musicServiceProvider);

  StreamSubscription<MusicSessionState>? _subscription;

  @override
  MusicSessionState build() {
    ref.onDispose(() => _subscription?.cancel());
    return MusicSessionState.initial;
  }

  /// Starts listening — call from `LogSessionScreen.initState` while showing
  /// a running (unfinished) session. Safe to call more than once; a second
  /// call just re-subscribes.
  Future<void> activate() async {
    await _subscription?.cancel();
    _subscription = _service.state.listen((s) => state = s);
    await _service.activate();
  }

  /// Stops listening — call from `LogSessionScreen.dispose`/on finish. Never
  /// pauses or otherwise touches actual playback.
  Future<void> deactivate() async {
    await _subscription?.cancel();
    _subscription = null;
    await _service.deactivate();
    state = MusicSessionState.initial;
  }

  Future<bool> isProviderInstalled(MusicProviderId provider) =>
      _service.isProviderInstalled(provider);

  Future<void> selectProvider(MusicProviderId provider) => _service.selectProvider(provider);

  Future<void> play() => _service.play();

  Future<void> pause() => _service.pause();

  Future<void> next() => _service.next();

  Future<void> previous() => _service.previous();

  Future<void> openProviderApp() => _service.openProviderApp();

  Future<void> requestPermission() => _service.requestPermission();

  Future<void> refresh() => _service.refresh();
}

final musicControllerProvider = NotifierProvider<MusicController, MusicSessionState>(MusicController.new);

/// Picks the platform-specific [MusicService]. Declared here (not in
/// music_service.dart, alongside [MusicServiceStub]) to avoid an import
/// cycle: this file needs to import `music_service_android.dart` to
/// construct [MusicServiceAndroid], and that file needs `music_service.dart`
/// for the [MusicService] interface it implements.
///
/// M2 shipped [MusicServiceAndroid]. M3/M4 (iOS Apple Music / Spotify App
/// Remote) will add the iOS branch here — until then, iOS (and any other
/// platform) still gets [MusicServiceStub] — see
/// docs/music/46-workout-music-controls-plan.md §3.2/§4.
final musicServiceProvider = Provider<MusicService>((ref) {
  final preferences = ref.read(musicPreferencesProvider);
  if (Platform.isAndroid) return MusicServiceAndroid(preferences);
  return MusicServiceStub(preferences);
});
