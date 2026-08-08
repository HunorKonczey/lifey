import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';

/// How long a received "is typing" stays on screen, and how often we tell the
/// server we are writing.
///
/// Both mirror `lifey.chat.typing-ttl` / `typing-throttle`. The throttle is the
/// shorter of the two on purpose: a steady typist's indicator is refreshed
/// before it can lapse, so it never flickers mid-sentence.
const chatTypingTtl = Duration(seconds: 5);
const chatTypingThrottle = Duration(seconds: 3);

/// Which threads the peer is writing in right now.
///
/// The one piece of chat state that exists **only** on the stream: there is no
/// REST equivalent, and there does not need to be. Losing a frame costs
/// nothing — the indicator simply doesn't appear — which is exactly why this
/// is allowed to break the plan's "the stream is never the truth" rule that
/// every other frame obeys (§19.4/1).
class ChatTypingController extends Notifier<Set<int>> {
  final _expiryTimers = <int, Timer>{};

  @override
  Set<int> build() {
    ref.onDispose(() {
      for (final timer in _expiryTimers.values) {
        timer.cancel();
      }
      _expiryTimers.clear();
    });
    return const {};
  }

  /// Applies a `typing` frame and schedules its own expiry. One timer per
  /// thread, replaced on every frame, so a steady typist keeps the indicator
  /// alive without a queue of pending timers behind it.
  void peerTyping(int conversationId) {
    _expiryTimers.remove(conversationId)?.cancel();
    _expiryTimers[conversationId] = Timer(chatTypingTtl, () {
      _expiryTimers.remove(conversationId);
      state = state.difference({conversationId});
    });
    if (!state.contains(conversationId)) {
      state = {...state, conversationId};
    }
  }

  bool isTypingIn(int conversationId) => state.contains(conversationId);
}

final chatTypingControllerProvider =
    NotifierProvider<ChatTypingController, Set<int>>(ChatTypingController.new);

/// Reports "I'm writing" at most once per [chatTypingThrottle].
///
/// The throttle lives here rather than in the composer so no screen has to
/// remember it, and so switching threads resets the window — otherwise the
/// first keystroke in a new thread would be swallowed by the previous one's.
class ChatTypingReporter {
  ChatTypingReporter(this._send);

  /// Just the one call it needs, rather than the whole repository: this class
  /// is a clock and a comparison, and the narrower seam keeps it testable
  /// without a database behind it.
  final Future<void> Function(int conversationId) _send;

  int? _conversationId;
  DateTime? _lastSentAt;

  void report(int conversationId) {
    final now = DateTime.now();
    if (conversationId != _conversationId) {
      _conversationId = conversationId;
      _lastSentAt = null;
    }
    final last = _lastSentAt;
    if (last != null && now.difference(last) < chatTypingThrottle) return;
    _lastSentAt = now;
    unawaited(_send(conversationId));
  }
}

final chatTypingReporterProvider = Provider<ChatTypingReporter>((ref) {
  return ChatTypingReporter(ref.watch(chatRepositoryProvider).sendTypingSignal);
});
