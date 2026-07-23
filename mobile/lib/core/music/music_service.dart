import 'dart:async';
import 'dart:typed_data';

import 'music_preferences.dart';
import 'music_provider_id.dart';

/// Where a [MusicSessionState] currently sits — drives which body
/// `MusicPlayerSheet` renders and whether `MusicStickyButton` shows an
/// attention dot (docs/music/46-workout-music-controls-plan.md §3.2).
enum MusicConnectionStatus {
  /// No provider chosen yet — the sticky button routes to the picker
  /// instead of this sheet in this state; kept here mainly as a defensive
  /// fallback for the player sheet.
  notConfigured,

  /// Android only: notification access hasn't been granted yet.
  permissionNeeded,

  /// iOS Spotify only: about to hand off to the Spotify app to establish the
  /// App Remote connection — shown *before* that handoff so it doesn't feel
  /// like an unexplained app-switch (docs/music/46-workout-music-controls-plan.md §2.2).
  connectPrompt,

  /// The chosen provider app isn't installed on this device.
  appNotInstalled,

  /// Connected to the platform bridge, but the chosen app isn't currently
  /// playing anything.
  noActiveSession,

  /// A connection attempt (e.g. iOS Spotify App Remote) is in flight.
  connecting,

  /// Connected and (per [MusicSessionState.playback]) either playing or
  /// paused — both render the same sheet, just a different play/pause glyph.
  connected,

  /// The bridge reported a failure (lost connection, unexpected native
  /// error) — distinct from [appNotInstalled], which is a known, named state.
  error,
}

/// Now-playing metadata + transport state for a [connected] session. Only
/// what the UI needs (docs/music/46-workout-music-controls-plan.md §3.2) —
/// deliberately no playback position: no platform bridge here pushes it
/// continuously, and the transport controls don't need it.
class MusicPlaybackState {
  const MusicPlaybackState({
    this.title,
    this.artist,
    this.artworkPng,
    required this.isPlaying,
  });

  final String? title;
  final String? artist;

  /// Album artwork, already decoded to PNG bytes by the native side. Null
  /// shows the placeholder glyph instead.
  final Uint8List? artworkPng;
  final bool isPlaying;

  /// Decodes `MediaSessionBridge.kt`'s event payload (M2) — `artworkPng`
  /// arrives as a `Uint8List` directly (the standard codec maps a Kotlin
  /// `ByteArray` straight to `Uint8List`, not a generic `List`).
  factory MusicPlaybackState.fromJson(Map<Object?, Object?> json) => MusicPlaybackState(
        title: json['title'] as String?,
        artist: json['artist'] as String?,
        artworkPng: json['artworkPng'] as Uint8List?,
        isPlaying: json['isPlaying'] as bool? ?? false,
      );
}

/// The full state `MusicController`/`MusicStickyButton`/`MusicPlayerSheet`
/// render from.
class MusicSessionState {
  const MusicSessionState({
    this.provider,
    required this.status,
    this.playback,
  });

  static const initial = MusicSessionState(status: MusicConnectionStatus.notConfigured);

  final MusicProviderId? provider;
  final MusicConnectionStatus status;

  /// Non-null only while [status] is [MusicConnectionStatus.connected].
  final MusicPlaybackState? playback;

  /// Decodes `MediaSessionBridge.kt`'s event payload (M2): `{"status":
  /// "...", "provider": "spotify"|null, "playback": {...}|null}` — the
  /// `provider`/`status` strings are always the exact enum member names
  /// (Kotlin only ever echoes back what Dart sent it, or one of the fixed
  /// status literals from docs/music/46-workout-music-controls-plan.md §2.1).
  factory MusicSessionState.fromJson(Map<Object?, Object?> json) {
    final providerName = json['provider'] as String?;
    final playbackJson = json['playback'] as Map<Object?, Object?>?;
    return MusicSessionState(
      provider: providerName == null ? null : MusicProviderId.values.byName(providerName),
      status: MusicConnectionStatus.values.byName(json['status'] as String),
      playback: playbackJson == null ? null : MusicPlaybackState.fromJson(playbackJson),
    );
  }
}

/// Platform-neutral facade over whichever music app the user picked —
/// mirrors `WatchWorkoutService`'s shape (methods + a state stream, injected
/// via a Riverpod provider) so `MusicController` can stay a thin pass-through.
///
/// M2 added `MusicServiceAndroid` (music_service_android.dart), backed by
/// `MediaSessionBridge.kt`/`MusicSessionManager` — one implementation covers
/// all three providers on Android. M3/M4 will add the iOS implementations
/// (Apple Music / Spotify App Remote); until then, non-Android platforms
/// still get [MusicServiceStub]. The platform choice is made in
/// `music_controller.dart`'s `musicServiceProvider` (not here, to avoid an
/// import cycle with music_service_android.dart) — see
/// docs/music/46-workout-music-controls-plan.md §3.2/§4.
abstract class MusicService {
  /// Broadcasts every state change from the moment [activate] is called
  /// until [deactivate]. Implementations should replay the current state to
  /// new listeners so a rebuild after a hot state change doesn't miss it.
  Stream<MusicSessionState> get state;

  /// Starts listening to the platform bridge for the previously-selected
  /// provider (if any) — called once per running-session screen instance,
  /// see docs/music/46-workout-music-controls-plan.md §3.3. Safe to call
  /// again without an intervening [deactivate] (e.g. app resume).
  Future<void> activate();

  /// Stops listening — called when the log-session screen for a running
  /// workout unmounts or the session finishes. Never touches the music
  /// itself: whatever is playing keeps playing, we just stop watching.
  Future<void> deactivate();

  /// Whether [provider]'s app is installed on this device. Always `true` in
  /// [MusicServiceStub] (no real detection until M2/M3/M4's native queries
  /// exist) — see docs/music/46-workout-music-controls-plan.md §2.1/§2.2.
  Future<bool> isProviderInstalled(MusicProviderId provider);

  /// Persists [provider] as the chosen app and (re)connects to it.
  Future<void> selectProvider(MusicProviderId provider);

  Future<void> play();
  Future<void> pause();
  Future<void> next();
  Future<void> previous();

  /// Launches the chosen provider's app directly — used from the
  /// [MusicConnectionStatus.noActiveSession] empty state's CTA.
  Future<void> openProviderApp();

  /// Requests whatever the current [MusicConnectionStatus] is blocked on:
  /// Android notification access (deep-links to system settings), iOS Apple
  /// Music library authorization, or iOS Spotify App Remote's connect/wake
  /// handshake — docs/music/46-workout-music-controls-plan.md §3.2.
  Future<void> requestPermission();

  /// Re-syncs against the platform bridge without a full [deactivate] +
  /// [activate] cycle — called on app resume and from the player sheet's
  /// "Try again" action (docs/music/46-workout-music-controls-plan.md §3.3).
  Future<void> refresh();
}

/// M1 stand-in: no platform bridge, but a fully working state machine for
/// provider selection so the whole UI (picker, sticky button, player sheet)
/// is clickable end to end before any native code exists
/// (docs/music/46-workout-music-controls-plan.md §4, M1). Once a provider is
/// selected it always reports [MusicConnectionStatus.noActiveSession] — the
/// real "is something actually playing" answer only exists once M2/M3/M4
/// wire up a real platform bridge.
class MusicServiceStub implements MusicService {
  MusicServiceStub(this._preferences);

  final MusicPreferences _preferences;
  // `sync: true` so `.add()` delivers to the current listener immediately
  // instead of on a later microtask/event-loop turn. A non-sync broadcast
  // controller deferred delivery just enough that an `_emit` fired from
  // inside an already-awaited call (e.g. `activate()`'s
  // `await _preferences.selectedProvider()` then `_emit(...)`) could still
  // be sitting undelivered by the time that `await` in the caller resolved
  // — `MusicController.activate()`/`selectProvider()` would then read a
  // stale status. Safe here since nothing re-enters `_emit` from within a
  // listener callback on this same stream.
  final _controller = StreamController<MusicSessionState>.broadcast(sync: true);
  MusicSessionState _current = MusicSessionState.initial;

  void _emit(MusicSessionState next) {
    _current = next;
    _controller.add(next);
  }

  @override
  Stream<MusicSessionState> get state => _controller.stream;

  @override
  Future<void> activate() async {
    final provider = await _preferences.selectedProvider();
    _emit(MusicSessionState(
      provider: provider,
      status: provider == null
          ? MusicConnectionStatus.notConfigured
          : MusicConnectionStatus.noActiveSession,
    ));
  }

  @override
  Future<void> deactivate() async {
    // Nothing to tear down — no real bridge is listening yet.
  }

  @override
  Future<bool> isProviderInstalled(MusicProviderId provider) async => true;

  @override
  Future<void> selectProvider(MusicProviderId provider) async {
    await _preferences.setSelectedProvider(provider);
    _emit(MusicSessionState(provider: provider, status: MusicConnectionStatus.noActiveSession));
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> openProviderApp() async {}

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> refresh() async {
    if (_current.provider != null) {
      _emit(MusicSessionState(
        provider: _current.provider,
        status: MusicConnectionStatus.noActiveSession,
      ));
    }
  }
}
