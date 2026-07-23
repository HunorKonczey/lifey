import 'package:flutter/services.dart';

import 'music_preferences.dart';
import 'music_provider_id.dart';
import 'music_service.dart';

/// Android implementation of [MusicService] — a thin wrapper over the
/// `lifey/music` MethodChannel + `lifey/music/events` EventChannel, backed by
/// `MediaSessionBridge.kt`'s use of `MediaSessionManager`
/// (docs/music/46-workout-music-controls-plan.md §2.1, M2). One
/// implementation covers all three providers: the platform sees every app's
/// active media session, and the native side filters by package name for
/// whichever provider is currently selected.
///
/// Every native call is best-effort and never throws, mirroring
/// `WatchWorkoutService` — until `MediaSessionBridge` is registered from
/// `MainActivity`, calling a method with no handler throws
/// `MissingPluginException`, caught and swallowed here exactly like a
/// genuinely absent bridge.
class MusicServiceAndroid implements MusicService {
  MusicServiceAndroid(this._preferences, {MethodChannel? channel, EventChannel? eventChannel})
      : _channel = channel ?? const MethodChannel('lifey/music'),
        _eventChannel = eventChannel ?? const EventChannel('lifey/music/events');

  final MusicPreferences _preferences;
  final MethodChannel _channel;
  final EventChannel _eventChannel;

  Stream<MusicSessionState>? _events;

  @override
  Stream<MusicSessionState> get state {
    return _events ??= _eventChannel.receiveBroadcastStream().map(
          (raw) => MusicSessionState.fromJson(Map<Object?, Object?>.from(raw as Map)),
        );
  }

  /// Tells the native side which provider (if any) was persisted, and lets
  /// it (re)register its `MediaSessionManager` listener + emit the current
  /// status. The native side deliberately doesn't remember the selected
  /// provider across a [deactivate]/[activate] cycle on its own — this call
  /// is always the source of truth, read fresh from [_preferences] every
  /// time, so a provider switch that happened while inactive is picked up
  /// correctly.
  @override
  Future<void> activate() async {
    final provider = await _preferences.selectedProvider();
    await _invoke('activate', {'providerId': provider?.name});
  }

  @override
  Future<void> deactivate() => _invoke('deactivate');

  @override
  Future<bool> isProviderInstalled(MusicProviderId provider) async {
    try {
      return await _channel.invokeMethod<bool>('isProviderInstalled', {'providerId': provider.name}) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> selectProvider(MusicProviderId provider) async {
    await _preferences.setSelectedProvider(provider);
    await _invoke('selectProvider', {'providerId': provider.name});
  }

  @override
  Future<void> play() => _invoke('play');

  @override
  Future<void> pause() => _invoke('pause');

  @override
  Future<void> next() => _invoke('next');

  @override
  Future<void> previous() => _invoke('previous');

  @override
  Future<void> openProviderApp() => _invoke('openProviderApp');

  /// Deep-links to the system's notification-access settings screen
  /// (docs/music/46-workout-music-controls-plan.md §2.1). No return value —
  /// the native side observes the grant asynchronously via
  /// `NotificationListenerService.onListenerConnected` and pushes a fresh
  /// state on [state] the moment Android (re)binds the listener, so nothing
  /// here needs to poll for the result.
  @override
  Future<void> requestPermission() => _invoke('requestPermission');

  @override
  Future<void> refresh() => _invoke('refresh');

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _channel.invokeMethod(method, arguments);
    } catch (_) {
      // Best-effort, see class doc.
    }
  }
}
