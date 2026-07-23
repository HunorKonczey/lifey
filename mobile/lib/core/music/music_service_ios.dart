import 'dart:async';

import 'package:flutter/services.dart';

import 'music_preferences.dart';
import 'music_provider_id.dart';
import 'music_service.dart';

/// iOS implementation of [MusicService] — M3
/// (docs/music/46-workout-music-controls-plan.md §2.2, §4). Real control only
/// exists for [MusicProviderId.appleMusic], via the `lifey/music`
/// MethodChannel + `lifey/music/events` EventChannel backed by
/// `AppleMusicBridge.swift` (`MPMusicPlayerController.systemMusicPlayer`) —
/// the same channel names `MusicServiceAndroid` uses, since a build only ever
/// registers one native side or the other.
///
/// Any other provider (Spotify — YouTube Music is already excluded from the
/// picker by [MusicProviderIdX.isSupportedOnThisPlatform]) falls back to the
/// same always-`noActiveSession`/`notConfigured` behavior [MusicServiceStub]
/// used for every provider in M1: selectable in the picker per the platform
/// support matrix (§2.3), but not yet wired to a real bridge. M4 replaces
/// this fallback with the `spotify_sdk` App Remote composite.
class MusicServiceIos implements MusicService {
  MusicServiceIos(this._preferences, {MethodChannel? channel, EventChannel? eventChannel})
      : _channel = channel ?? const MethodChannel('lifey/music'),
        _eventChannel = eventChannel ?? const EventChannel('lifey/music/events');

  final MusicPreferences _preferences;
  final MethodChannel _channel;
  final EventChannel _eventChannel;

  // `sync: true` for the same reason as MusicServiceStub — an `_emit` inside
  // an already-awaited call must land before that await's caller resumes.
  final _controller = StreamController<MusicSessionState>.broadcast(sync: true);
  StreamSubscription<dynamic>? _nativeSubscription;
  MusicProviderId? _activeProvider;

  @override
  Stream<MusicSessionState> get state => _controller.stream;

  @override
  Future<void> activate() async {
    final provider = await _preferences.selectedProvider();
    await _switchTo(provider);
  }

  @override
  Future<void> deactivate() async {
    await _nativeSubscription?.cancel();
    _nativeSubscription = null;
    if (_activeProvider == MusicProviderId.appleMusic) {
      await _invoke('deactivate');
    }
    _activeProvider = null;
  }

  @override
  Future<bool> isProviderInstalled(MusicProviderId provider) async => true;

  @override
  Future<void> selectProvider(MusicProviderId provider) async {
    await _preferences.setSelectedProvider(provider);
    await _switchTo(provider);
  }

  /// (Re)points the outward [state] stream at either the real Apple Music
  /// bridge or the M1-style fallback, tearing down whichever was active
  /// before. Handles both [activate] (provider read from prefs) and
  /// [selectProvider] (a live switch mid-session via the player sheet's
  /// "Switch" action) — the only difference is who's asking.
  Future<void> _switchTo(MusicProviderId? provider) async {
    await _nativeSubscription?.cancel();
    _nativeSubscription = null;
    if (_activeProvider == MusicProviderId.appleMusic && provider != MusicProviderId.appleMusic) {
      await _invoke('deactivate');
    }
    _activeProvider = provider;
    if (provider == MusicProviderId.appleMusic) {
      _nativeSubscription = _eventChannel.receiveBroadcastStream().listen((raw) {
        _controller.add(MusicSessionState.fromJson(Map<Object?, Object?>.from(raw as Map)));
      });
      await _invoke('activate', {'providerId': provider!.name});
    } else {
      _controller.add(MusicSessionState(
        provider: provider,
        status: provider == null
            ? MusicConnectionStatus.notConfigured
            : MusicConnectionStatus.noActiveSession,
      ));
    }
  }

  @override
  Future<void> play() => _forwardIfAppleMusic('play');

  @override
  Future<void> pause() => _forwardIfAppleMusic('pause');

  @override
  Future<void> next() => _forwardIfAppleMusic('next');

  @override
  Future<void> previous() => _forwardIfAppleMusic('previous');

  @override
  Future<void> openProviderApp() => _forwardIfAppleMusic('openProviderApp');

  @override
  Future<void> requestPermission() => _forwardIfAppleMusic('requestPermission');

  @override
  Future<void> refresh() => _forwardIfAppleMusic('refresh');

  /// Every transport/permission/refresh call is a no-op for the fallback
  /// branch — same as [MusicServiceStub], which never had anything to
  /// forward these to either.
  Future<void> _forwardIfAppleMusic(String method) {
    if (_activeProvider != MusicProviderId.appleMusic) return Future.value();
    return _invoke(method);
  }

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _channel.invokeMethod(method, arguments);
    } catch (_) {
      // Best-effort, mirrors MusicServiceAndroid.
    }
  }
}
