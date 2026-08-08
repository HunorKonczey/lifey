import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/chat/application/chat_typing_controller.dart';

/// The one piece of chat state that lives only on the stream (§19.4/1): it
/// arrives as a frame, expires on its own, and is never written down.
void main() {
  group('ChatTypingController', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    ChatTypingController controller() =>
        container.read(chatTypingControllerProvider.notifier);

    test('nobody is typing until a frame says so', () {
      expect(container.read(chatTypingControllerProvider), isEmpty);
      expect(controller().isTypingIn(12), isFalse);
    });

    test('a frame marks that thread, and only that thread', () {
      controller().peerTyping(12);

      expect(controller().isTypingIn(12), isTrue);
      expect(controller().isTypingIn(99), isFalse);
    });

    testWidgets('the indicator lapses on its own after the TTL', (tester) async {
      controller().peerTyping(12);
      expect(controller().isTypingIn(12), isTrue);

      // Nothing tells us the peer stopped — the frame simply isn't renewed,
      // which is why the expiry has to be the client's own business.
      await tester.pump(chatTypingTtl + const Duration(milliseconds: 100));

      expect(controller().isTypingIn(12), isFalse);
    });

    testWidgets('a second frame pushes the expiry out instead of stacking timers',
        (tester) async {
      controller().peerTyping(12);
      await tester.pump(chatTypingTtl - const Duration(seconds: 1));

      controller().peerTyping(12);
      // Past the first frame's deadline: a steady typist must not flicker.
      await tester.pump(const Duration(seconds: 2));
      expect(controller().isTypingIn(12), isTrue);

      await tester.pump(chatTypingTtl);
      expect(controller().isTypingIn(12), isFalse);
    });
  });

  group('ChatTypingReporter', () {
    test('a run of keystrokes costs one request, not one per key', () {
      final sent = <int>[];
      final reporter = ChatTypingReporter((id) async => sent.add(id));

      reporter.report(12);
      reporter.report(12);
      reporter.report(12);

      expect(sent, [12]);
    });

    test('switching threads resets the window', () {
      final sent = <int>[];
      final reporter = ChatTypingReporter((id) async => sent.add(id));

      reporter.report(12);
      // Otherwise the first keystroke in the new thread would be swallowed by
      // the previous thread's window.
      reporter.report(99);

      expect(sent, [12, 99]);
    });
  });
}
