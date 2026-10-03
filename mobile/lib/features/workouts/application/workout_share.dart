/// Looks for a session's server id, nudging the outbox between looks.
///
/// A workout is shared moments after it finishes, often before the sync engine
/// has created the session on the server — so the id the card needs does not
/// exist yet. This asks for a flush and looks again, a few times; the caller
/// bounds the whole wait (`ChatShareService.share`) and sends the card either
/// way, so a missing id costs the trainer a tap target, never the share
/// (docs/chat/83-chat-result-card-plan.md §2.6).
///
/// [lookup] reads the local row's server id; [flush] asks the sync engine to
/// push. Both are injected so the wait itself can be tested without a database.
Future<int?> pollSessionServerId({
  required Future<int?> Function() lookup,
  required Future<void> Function() flush,
  int attempts = 6,
  Duration pause = const Duration(milliseconds: 500),
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    final id = await lookup();
    if (id != null) return id;
    try {
      await flush();
    } catch (_) {
      // Offline or already running: the next look is the answer either way.
    }
    if (attempt < attempts - 1) await Future<void>.delayed(pause);
  }
  return lookup();
}
