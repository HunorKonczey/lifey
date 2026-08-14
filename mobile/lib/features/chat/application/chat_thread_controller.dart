import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../domain/chat_message.dart';

/// One thread's messages, oldest first (the order they render in).
///
/// The stream is the local cache, so the thread opens instantly and works
/// offline; the network only ever *adds* to it. Paging is keyset and walks
/// upwards on demand — see [loadOlder].
class ChatThreadController extends StreamNotifier<List<ChatMessage>> {
  ChatThreadController(this.conversationId);

  final int conversationId;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  /// Goes false once the server says there is nothing older left, so the
  /// scroll listener stops asking.
  bool _hasMoreHistory = true;
  bool _loadingHistory = false;

  /// How many of the newest messages are on screen. Grows one page at a time
  /// as the reader walks back; the thread opens on a single page no matter how
  /// much of the conversation this device has cached.
  int _window = ChatRepository.pageSize;

  /// Points the stream at the current [_window]. Assigned in [build].
  void Function()? _resubscribe;

  bool get hasMoreHistory => _hasMoreHistory;

  /// Re-subscribing rather than rebuilding the provider: `ref.invalidateSelf()`
  /// would put the screen back through its loading state, which for a widened
  /// window means flashing a skeleton over a thread the reader is looking at.
  @override
  Stream<List<ChatMessage>> build() {
    final out = StreamController<List<ChatMessage>>();
    StreamSubscription<List<ChatMessage>>? subscription;

    void subscribe() {
      final previous = subscription;
      subscription = _repo
          .watchMessages(conversationId, limit: _window)
          .listen(out.add, onError: out.addError);
      unawaited(previous?.cancel());
    }

    _resubscribe = subscribe;
    subscribe();
    ref.onDispose(() {
      unawaited(subscription?.cancel());
      unawaited(out.close());
    });

    unawaited(catchUp());
    return out.stream;
  }

  /// Opening, and every app resume: pull whatever arrived while we were away
  /// (gap fill above the newest id we hold), re-read the newest page so a
  /// deletion the gap fill cannot see lands too, replay anything still unsent,
  /// and acknowledge the thread as read.
  Future<void> catchUp() async {
    try {
      await _repo.loadNewer(conversationId);
      // Costs one extra page on open/resume and is what makes a peer's
      // deletion visible without a live stream frame — see the repository's
      // note on why forward-only paging can't do it.
      await _repo.reconcileNewestPage(conversationId);
      await _repo.flushPending();
      await _repo.markRead(conversationId);
    } catch (_) {
      // Offline or a flaky network: the cached thread is still on screen and
      // the composer still works. Nothing to report.
    }
  }

  /// One page further back. Guarded against re-entry so a fast scroll can't
  /// fire several overlapping page loads.
  ///
  /// Two sources, in this order: rows already on the device — widening the
  /// window costs a local query and no network at all — and only once those
  /// run out, a page from the server.
  Future<void> loadOlder() async {
    if (_loadingHistory) return;
    _loadingHistory = true;
    try {
      final cached = await _repo.countMessages(conversationId);
      if (_window >= cached) {
        if (!_hasMoreHistory) return;
        try {
          _hasMoreHistory = await _repo.loadOlder(conversationId);
        } catch (_) {
          // Leave _hasMoreHistory alone — a failed page is worth retrying on
          // the next scroll, unlike a page that genuinely came back empty.
          return;
        }
      }
      _window += ChatRepository.pageSize;
      _resubscribe?.call();
    } finally {
      _loadingHistory = false;
    }
  }

  Future<void> send(String body, {File? image}) =>
      _repo.send(conversationId, body, image: image);

  Future<void> retry(String clientId) => _repo.retry(conversationId, clientId);

  Future<void> discard(String clientId) => _repo.discardUnsent(conversationId, clientId);

  Future<void> delete(String clientId) => _repo.deleteMessage(conversationId, clientId);

  Future<void> markRead() => _repo.markRead(conversationId);
}

final chatThreadControllerProvider =
    StreamNotifierProvider.family<ChatThreadController, List<ChatMessage>, int>(
  ChatThreadController.new,
);

/// Upload progress per `clientMessageId`, so a picture's bubble can show how
/// far its bytes have got. Empty when nothing is in flight.
final chatUploadProgressProvider = StreamProvider<Map<String, double>>((ref) {
  return ref.watch(chatRepositoryProvider).watchUploadProgress();
});

/// The thread's own conversation row (peer name, archived flag), watched
/// locally so the header renders before — and without — a network call.
final chatConversationProvider =
    StreamProvider.family((ref, int conversationId) {
  return ref.watch(chatRepositoryProvider).watchConversation(conversationId);
});
