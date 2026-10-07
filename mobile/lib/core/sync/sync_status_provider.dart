import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local_db/app_database.dart';
import '../local_db/database_provider.dart';
import 'outbox_dependencies.dart';

enum SyncState { pending, syncing, failed }

/// A record's outstanding sync state, surfaced next to it in list UIs.
class EntitySyncStatus {
  const EntitySyncStatus({required this.state, this.lastError});

  final SyncState state;

  /// Set only when [state] is [SyncState.failed].
  final String? lastError;
}

/// Raw outbox rows, watched live.
final pendingOperationsProvider = StreamProvider<List<PendingOperationRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.select(db.pendingOperations).watch();
});

/// Derives each clientId's worst outstanding status from [pendingOperationsProvider]
/// — a clientId can have more than one queued operation (e.g. an update
/// queued behind a still-pending create); `failed` always wins so a problem
/// is never hidden behind an unrelated pending row for the same entity.
final syncStatusByClientIdProvider = Provider<Map<String, EntitySyncStatus>>((ref) {
  final ops = ref.watch(pendingOperationsProvider).value ?? const [];
  final result = <String, EntitySyncStatus>{};
  for (final op in ops) {
    final state = switch (op.status) {
      'failed' => SyncState.failed,
      'syncing' => SyncState.syncing,
      _ => SyncState.pending,
    };
    final current = result[op.clientId];
    if (current == null || (state == SyncState.failed && current.state != SyncState.failed)) {
      result[op.clientId] = EntitySyncStatus(state: state, lastError: op.lastError);
    }
  }
  // An operation waiting on a create that failed for good never goes out and
  // never says so: its own row stays a neutral `pending`, so a meal logged
  // with a food that was rejected looked like it was syncing for ever. It is
  // surfaced as failed with the root cause, and its retry retries the cause
  // ([OutboxWriter.retry]).
  for (final entry in blockedByFailure(ops).entries) {
    if (result[entry.key]?.state == SyncState.failed) continue;
    result[entry.key] = EntitySyncStatus(state: SyncState.failed, lastError: entry.value);
  }
  return result;
});
