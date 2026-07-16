import 'dart:async';

/// FIFO async mutex shared between [SyncEngine] and [PullEngine] so a push
/// (outbox drain) and a pull (server refresh) never run concurrently.
///
/// Without this, a pull's GET for an entity can be in flight — fetching the
/// pre-edit server snapshot — while an independent, unawaited push (e.g.
/// [OutboxWriter]'s `_kick()` firing off the back of a local edit) completes
/// and clears its `pending_operations` row before the pull's response comes
/// back. [PullEngine]'s per-row "skip if pending" guard only protects
/// against an overwrite while an operation is still queued; it can't detect
/// that the GET response itself predates a push that already landed. Forcing
/// pull and push to run one at a time closes that window: a pull that starts
/// after a push either sees the update already reflected server-side, or —
/// if it started first — waits for the push to finish, by which time the
/// pending operation it raced against is still queued and its guard fires.
class SyncLock {
  Future<void> _tail = Future<void>.value();

  Future<T> synchronized<T>(Future<T> Function() action) {
    final previous = _tail;
    final completer = Completer<void>();
    _tail = completer.future;
    return previous.then((_) async {
      try {
        return await action();
      } finally {
        completer.complete();
      }
    });
  }
}
