import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/chat/application/chat_online_controller.dart';
import 'package:lifey/features/chat/application/chat_stream_controller.dart';
import 'package:lifey/features/chat/data/chat_repository.dart';
import 'package:lifey/features/chat/data/chat_stream_client.dart';

/// Who of my thread peers has the app open (LIF-122): it arrives as `online` frames, is never stored, and is wiped whenever our
/// own stream is down - an "online" we cannot confirm is worse than none.
class _Repository extends Fake implements ChatRepository {
  @override
  Future<int?> newestServerIdAcrossThreads() async => null;

  @override
  Future<void> setPresence(int? activeConversationId) async {}
}

class _Client extends Fake implements ChatStreamClient {
  void Function(ChatStreamFrame frame)? onFrame;
  void Function(bool connected)? onConnectionChange;

  @override
  void connect({
    required Future<int?> Function() lastEventId,
    required void Function(ChatStreamFrame frame) onFrame,
    void Function(bool connected)? onConnectionChange,
  }) {
    this.onFrame = onFrame;
    this.onConnectionChange = onConnectionChange;
  }

  @override
  Future<void> disconnect() async {}
}

ChatStreamFrame _online(int userId, bool online) =>
    ChatStreamFrame(name: 'online', data: {'userId': userId, 'online': online});

void main() {
  group('ChatOnlineController', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    ChatOnlineController controller() => container.read(chatOnlineControllerProvider.notifier);

    test('nobody is online until a frame says so', () {
      expect(container.read(chatOnlineControllerProvider), isEmpty);
      expect(controller().isOnline(8), isFalse);
    });

    test('a frame marks that person, and only them; the next one clears them again', () {
      controller().peerChanged(8, online: true);
      controller().peerChanged(9, online: true);
      expect(controller().isOnline(8), isTrue);
      expect(controller().isOnline(9), isTrue);

      controller().peerChanged(8, online: false);
      expect(controller().isOnline(8), isFalse);
      expect(controller().isOnline(9), isTrue);
    });

    test('the same state twice changes nothing (no rebuild for a repeated frame)', () {
      var notifications = 0;
      container.listen(chatOnlineControllerProvider, (_, __) => notifications++);

      controller().peerChanged(8, online: true);
      controller().peerChanged(8, online: true);
      controller().peerChanged(9, online: false);

      expect(notifications, 1);
    });

    test('clear forgets everybody', () {
      controller().peerChanged(8, online: true);

      controller().clear();

      expect(container.read(chatOnlineControllerProvider), isEmpty);
    });
  });

  group('the stream feeds it', () {
    testWidgets('online frames reach the controller; our own stream dropping wipes it', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final client = _Client();
      final controller = ChatStreamController(
        _Repository(),
        client,
        onPeerTyping: (_) {},
        onPeerOnline: (userId, {required online}) =>
            container.read(chatOnlineControllerProvider.notifier).peerChanged(userId, online: online),
        onStreamDown: () => container.read(chatOnlineControllerProvider.notifier).clear(),
      );
      addTearDown(controller.dispose);

      client.onConnectionChange!(true);
      client.onFrame!(_online(8, true));
      client.onFrame!(_online(9, true));
      expect(container.read(chatOnlineControllerProvider), {8, 9});

      client.onFrame!(_online(8, false));
      expect(container.read(chatOnlineControllerProvider), {9});

      // A frame that does not say who or what is ignored rather than guessed at.
      client.onFrame!(const ChatStreamFrame(name: 'online', data: {'userId': 7}));
      expect(container.read(chatOnlineControllerProvider), {9});

      client.onConnectionChange!(false);
      expect(container.read(chatOnlineControllerProvider), isEmpty);
    });

    testWidgets('going to the background wipes it too', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final client = _Client();
      final controller = ChatStreamController(
        _Repository(),
        client,
        onPeerTyping: (_) {},
        onPeerOnline: (userId, {required online}) =>
            container.read(chatOnlineControllerProvider.notifier).peerChanged(userId, online: online),
        onStreamDown: () => container.read(chatOnlineControllerProvider.notifier).clear(),
      );
      addTearDown(controller.dispose);
      client.onFrame!(_online(8, true));
      expect(container.read(chatOnlineControllerProvider), {8});

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(container.read(chatOnlineControllerProvider), isEmpty);
    });
  });
}
