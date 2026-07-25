import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/music/music_preferences.dart';
import 'package:lifey/core/music/music_provider_id.dart';
import 'package:lifey/core/music/music_service.dart';
import 'package:lifey/core/music/music_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MusicServiceAndroid — MethodChannel calls', () {
    const channel = MethodChannel('lifey/music');
    final calls = <MethodCall>[];

    void setHandler(Future<Object?> Function(MethodCall) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, handler);
    }

    setUp(() {
      calls.clear();
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('a native call throwing MissingPluginException is swallowed, not rethrown', () async {
      // No handler registered — mirrors the real state before
      // MediaSessionBridge.kt is registered from MainActivity.
      final service = MusicServiceAndroid(MusicPreferences());

      await expectLater(service.activate(), completes);
      expect(await service.isProviderInstalled(MusicProviderId.spotify), isFalse);
    });

    test('activate() reads the persisted provider and sends its name', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      await MusicPreferences().setSelectedProvider(MusicProviderId.appleMusic);
      final service = MusicServiceAndroid(MusicPreferences());

      await service.activate();

      expect(calls.single.method, 'activate');
      expect(calls.single.arguments, {'providerId': 'appleMusic'});
    });

    test('activate() with nothing chosen yet sends a null providerId', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = MusicServiceAndroid(MusicPreferences());

      await service.activate();

      expect(calls.single.arguments, {'providerId': null});
    });

    test('selectProvider() persists the choice and sends it natively', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = MusicServiceAndroid(MusicPreferences());

      await service.selectProvider(MusicProviderId.youtubeMusic);

      expect(calls.single.method, 'selectProvider');
      expect(calls.single.arguments, {'providerId': 'youtubeMusic'});
      expect(await MusicPreferences().selectedProvider(), MusicProviderId.youtubeMusic);
    });

    test('isProviderInstalled() returns the native answer', () async {
      setHandler((call) async {
        calls.add(call);
        return true;
      });
      final service = MusicServiceAndroid(MusicPreferences());

      expect(await service.isProviderInstalled(MusicProviderId.spotify), isTrue);
      expect(calls.single.arguments, {'providerId': 'spotify'});
    });

    test('deactivate/play/pause/next/previous/openProviderApp/requestPermission/refresh '
        'call their matching native methods with no arguments', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      final service = MusicServiceAndroid(MusicPreferences());

      await service.deactivate();
      await service.play();
      await service.pause();
      await service.next();
      await service.previous();
      await service.openProviderApp();
      await service.requestPermission();
      await service.refresh();

      expect(calls.map((c) => c.method).toList(), [
        'deactivate',
        'play',
        'pause',
        'next',
        'previous',
        'openProviderApp',
        'requestPermission',
        'refresh',
      ]);
      expect(calls.every((c) => c.arguments == null), isTrue);
    });
  });

  group('MusicServiceAndroid — events', () {
    const eventChannel = EventChannel('lifey/music/events');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(eventChannel, null);
    });

    test('decodes a noActiveSession status with a provider and no playback', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({'status': 'noActiveSession', 'provider': 'spotify', 'playback': null});
          },
        ),
      );
      final service = MusicServiceAndroid(MusicPreferences());

      final state = await service.state.first;

      expect(state.status, MusicConnectionStatus.noActiveSession);
      expect(state.provider, MusicProviderId.spotify);
      expect(state.playback, isNull);
    });

    test('decodes a connected status with full playback metadata + artwork bytes', () async {
      final artwork = Uint8List.fromList([1, 2, 3, 4]);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({
              'status': 'connected',
              'provider': 'appleMusic',
              'playback': {
                'title': 'Neon Horizon',
                'artist': 'Kavarga',
                'artworkPng': artwork,
                'isPlaying': true,
              },
            });
          },
        ),
      );
      final service = MusicServiceAndroid(MusicPreferences());

      final state = await service.state.first;

      expect(state.status, MusicConnectionStatus.connected);
      expect(state.provider, MusicProviderId.appleMusic);
      expect(state.playback!.title, 'Neon Horizon');
      expect(state.playback!.artist, 'Kavarga');
      expect(state.playback!.artworkPng, artwork);
      expect(state.playback!.isPlaying, isTrue);
    });

    test('decodes a permissionNeeded status', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({'status': 'permissionNeeded', 'provider': 'spotify', 'playback': null});
          },
        ),
      );
      final service = MusicServiceAndroid(MusicPreferences());

      final state = await service.state.first;

      expect(state.status, MusicConnectionStatus.permissionNeeded);
    });
  });
}
