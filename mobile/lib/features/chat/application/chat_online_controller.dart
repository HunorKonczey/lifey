import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which of the people I share a thread with have the app open right now (LIF-122).
///
/// Like the typing hint it lives **only** on the stream: nothing is stored and there is no REST equivalent. The server sends
/// the starting state on every (re)connect and the changes after it; this state is wiped whenever our own stream is down, because
/// "online" we cannot confirm is worse than no dot at all (docs/chat/40-trainer-chat-plan.md section 22).
class ChatOnlineController extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  /// Applies an `online` frame.
  void peerChanged(int userId, {required bool online}) {
    if (online == state.contains(userId)) return;
    state = online ? {...state, userId} : state.difference({userId});
  }

  /// Our own stream dropped: nothing is known about anybody any more.
  void clear() {
    if (state.isNotEmpty) state = const {};
  }

  bool isOnline(int userId) => state.contains(userId);
}

final chatOnlineControllerProvider = NotifierProvider<ChatOnlineController, Set<int>>(ChatOnlineController.new);
