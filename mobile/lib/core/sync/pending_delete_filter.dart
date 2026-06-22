import '../local_db/app_database.dart';

/// ClientIds with a delete still in flight (queued or syncing, not yet
/// failed). A delete leaves its row (and any children) in storage until the
/// server confirms it — see `EntitySyncConfig.cleanupChildren`'s doc — so
/// every repository's `watchAll()` filters its list against this set to
/// hide those rows in the meantime. A *failed* delete is deliberately
/// excluded so the row reappears — with `SyncStatusIndicator`'s failed
/// marker — instead of staying hidden forever with no way to retry or
/// discard it.
Set<String> blockedByActiveDelete(List<PendingOperationRow> ops) => ops
    .where((op) => op.operation == 'delete' && op.status != 'failed')
    .map((op) => op.clientId)
    .toSet();
