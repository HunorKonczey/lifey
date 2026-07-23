import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/music/music_preferences.dart';
import 'package:lifey/core/music/music_provider_id.dart';
import 'package:lifey/core/music/music_service.dart';
import 'package:lifey/core/music/music_service_ios.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('lifey/music');
  const eventChannel = EventChannel('lifey/music/events');
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(eventChannel, null);
  });

  group('MusicServiceIos — Apple Music branch', () {
    test('activate() with appleMusic selected subscribes and sends providerId natively', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({'status': 'noActiveSession', 'provider': 'appleMusic', 'playback': null});
          },
        ),
      );
      await MusicPreferences().setSelectedProvider(MusicProviderId.appleMusic);
      final service = MusicServiceIos(MusicPreferences());

      final firstState = service.state.first;
      await service.activate();

      expect(calls.single.method, 'activate');
      expect(calls.single.arguments, {'providerId': 'appleMusic'});
      expect((await firstState).status, MusicConnectionStatus.noActiveSession);
    });

    test('a native call throwing MissingPluginException is swallowed, not rethrown', () async {
      await MusicPreferences().setSelectedProvider(MusicProviderId.appleMusic);
      final service = MusicServiceIos(MusicPreferences());

      await expectLater(service.activate(), completes);
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
      await MusicPreferences().setSelectedProvider(MusicProviderId.appleMusic);
      final service = MusicServiceIos(MusicPreferences());

      final firstState = service.state.first;
      await service.activate();
      final state = await firstState;

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
            events.success({'status': 'permissionNeeded', 'provider': 'appleMusic', 'playback': null});
          },
        ),
      );
      await MusicPreferences().setSelectedProvider(MusicProviderId.appleMusic);
      final service = MusicServiceIos(MusicPreferences());

      final firstState = service.state.first;
      await service.activate();

      expect((await firstState).status, MusicConnectionStatus.permissionNeeded);
    });

    test('play/pause/next/previous/openProviderApp/requestPermission/refresh '
        'call their matching native methods once appleMusic is active', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(onListen: (arguments, events) {}),
      );
      await MusicPreferences().setSelectedProvider(MusicProviderId.appleMusic);
      final service = MusicServiceIos(MusicPreferences());
      await service.activate();
      calls.clear();

      await service.play();
      await service.pause();
      await service.next();
      await service.previous();
      await service.openProviderApp();
      await service.requestPermission();
      await service.refresh();
      await service.deactivate();

      expect(calls.map((c) => c.method).toList(), [
        'play',
        'pause',
        'next',
        'previous',
        'openProviderApp',
        'requestPermission',
        'refresh',
        'deactivate',
      ]);
    });
  });

  group('MusicServiceIos — fallback branch (Spotify, pre-M4)', () {
    test('activate() with spotify selected reports noActiveSession without touching the native channel', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      await MusicPreferences().setSelectedProvider(MusicProviderId.spotify);
      final service = MusicServiceIos(MusicPreferences());

      final firstState = service.state.first;
      await service.activate();
      final state = await firstState;

      expect(state.status, MusicConnectionStatus.noActiveSession);
      expect(state.provider, MusicProviderId.spotify);
      expect(calls, isEmpty);
    });

    test('activate() with nothing chosen yet reports notConfigured', () async {
      final service = MusicServiceIos(MusicPreferences());

      final firstState = service.state.first;
      await service.activate();

      expect((await firstState).status, MusicConnectionStatus.notConfigured);
    });

    test('transport/permission/refresh calls are no-ops', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      await MusicPreferences().setSelectedProvider(MusicProviderId.spotify);
      final service = MusicServiceIos(MusicPreferences());
      await service.activate();

      await service.play();
      await service.pause();
      await service.next();
      await service.previous();
      await service.openProviderApp();
      await service.requestPermission();
      await service.refresh();

      expect(calls, isEmpty);
    });

    test('isProviderInstalled() is always true (no native detection yet)', () async {
      final service = MusicServiceIos(MusicPreferences());

      expect(await service.isProviderInstalled(MusicProviderId.spotify), isTrue);
      expect(await service.isProviderInstalled(MusicProviderId.appleMusic), isTrue);
    });
  });

  group('MusicServiceIos — switching providers mid-session', () {
    test('switching from appleMusic to spotify deactivates the native bridge', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(onListen: (arguments, events) {}),
      );
      final service = MusicServiceIos(MusicPreferences());
      await service.selectProvider(MusicProviderId.appleMusic);
      calls.clear();

      final firstState = service.state.first;
      await service.selectProvider(MusicProviderId.spotify);
      final state = await firstState;

      expect(calls.single.method, 'deactivate');
      expect(state.status, MusicConnectionStatus.noActiveSession);
      expect(state.provider, MusicProviderId.spotify);
    });

    test('switching from spotify to appleMusic activates the native bridge', () async {
      setHandler((call) async {
        calls.add(call);
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({'status': 'noActiveSession', 'provider': 'appleMusic', 'playback': null});
          },
        ),
      );
      final service = MusicServiceIos(MusicPreferences());
      await service.selectProvider(MusicProviderId.spotify);

      final firstState = service.state.first;
      await service.selectProvider(MusicProviderId.appleMusic);

      expect(calls.single.method, 'activate');
      expect(calls.single.arguments, {'providerId': 'appleMusic'});
      expect((await firstState).status, MusicConnectionStatus.noActiveSession);
    });
  });
}
