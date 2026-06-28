import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local_db/app_database.dart';
import '../local_db/database_provider.dart';
import 'entity_sync_config.dart';
import 'sync_engine.dart';
import 'sync_engine_provider.dart';

/// Writes `pending_operations` rows for the repositories and kicks the
/// [SyncEngine] so queued writes go out immediately when there's a
/// connection. Centralizes the one tricky rule: deleting (or updating) an
/// entity whose create hasn't synced yet has to be handled specially — the
/// backend has no row to PUT/DELETE.
class OutboxWriter {
  OutboxWriter(this._db, this._syncEngine);

  final AppDatabase _db;
  final SyncEngine _syncEngine;

  Future<void> enqueueCreate({
    required String clientId,
    required String entityType,
    required Map<String, dynamic> payload,
    String? dependsOnClientId,
  }) async {
    await _insert(
      clientId: clientId,
      entityType: entityType,
      operation: 'create',
      payload: payload,
      dependsOnClientId: dependsOnClientId,
    );
    _kick();
  }

  /// If this entity's create hasn't synced yet, the update is queued to
  /// depend on it (the sync engine will hold it until the create succeeds)
  /// rather than racing a PUT against a row the backend doesn't have yet.
  Future<void> enqueueUpdate({
    required String clientId,
    required String entityType,
    required Map<String, dynamic> payload,
  }) async {
    final createPending = await _hasPendingOperation(clientId, 'create');
    await _insert(
      clientId: clientId,
      entityType: entityType,
      operation: 'update',
      payload: payload,
      dependsOnClientId: createPending ? clientId : null,
    );
    _kick();
  }

  /// If the create for this entity never synced, deleting it locally is the
  /// whole story — every queued operation for it is dropped instead of
  /// enqueueing a delete the backend has no row for.
  ///
  /// Must be called *before* the caller considers removing its local row:
  /// the serverId the backend DELETE needs only exists in that row, and
  /// once it's gone there's no way to recover it.
  ///
  /// Returns whether a server-side delete was actually queued:
  /// - `true` — the caller must *not* delete its local row now. It should
  ///   stay in storage (hidden from list UIs by filtering on the pending
  ///   `delete` op — see e.g. `MealController.build`) so that if the
  ///   server rejects the delete (e.g. 409, still referenced elsewhere),
  ///   the row can reappear with [SyncStatusIndicator]'s failed marker
  ///   instead of vanishing with no way to retry or explain why. Only
  ///   [SyncEngine._applySuccess] deletes the row, once the server confirms.
  /// - `false` — nothing needs to reach the server (no create ever synced),
  ///   so the caller should delete its local row immediately; nothing else
  ///   ever will.
  Future<bool> enqueueDelete({required String clientId, required String entityType}) async {
    // Transacted: Drift defers a watched table's change notification until
    // the transaction commits, so observers (e.g.
    // activelyDeletingClientIdsProvider) only ever see the final state —
    // clearing the old ops and inserting the new `delete` op as two
    // separate writes would emit an intermediate snapshot with *no*
    // pending op for this clientId in between, which briefly un-hides the
    // row before the insert lands and hides it again.
    return _db.transaction(() async {
      final createPending = await _hasPendingOperation(clientId, 'create');
      await (_db.delete(_db.pendingOperations)..where((t) => t.clientId.equals(clientId))).go();
      if (createPending) return false;

      final tableName = entitySyncConfigs[entityType]!.tableName;
      final row = await _db
          .customSelect(
            'SELECT server_id FROM $tableName WHERE client_id = ?',
            variables: [Variable.withString(clientId)],
          )
          .getSingleOrNull();
      final serverId = row?.read<int?>('server_id');
      if (serverId == null) return false; // never synced — nothing to delete server-side

      await _insert(
        clientId: clientId,
        entityType: entityType,
        operation: 'delete',
        payload: {'serverId': serverId},
      );
      return true;
    }).then((queued) {
      if (queued) _kick();
      return queued;
    });
  }

  /// Resets every failed operation for [clientId] back to `pending` (and
  /// clears [PendingOperationRow.lastError]), then kicks the engine so the
  /// retry happens immediately rather than waiting for the next trigger.
  Future<void> retry(String clientId) async {
    await (_db.update(_db.pendingOperations)
          ..where((t) => t.clientId.equals(clientId) & t.status.equals('failed')))
        .write(const PendingOperationsCompanion(
      status: Value('pending'),
      lastError: Value(null),
    ));
    _kick();
  }

  /// Resets every non-network failed operation for [entityType] back to
  /// `pending` so that they are retried on the next sync pass. Useful when
  /// the underlying backend issue (e.g. a too-strict validation constraint)
  /// has been fixed server-side and stuck ops need a fresh attempt.
  /// Network-error failures already auto-retry, so they are left alone.
  Future<void> resetFailed(String entityType) async {
    final updated = await (_db.update(_db.pendingOperations)
          ..where((t) =>
              t.entityType.equals(entityType) &
              t.status.equals('failed') &
              t.lastError.isNotLike('[network] %')))
        .write(const PendingOperationsCompanion(
      status: Value('pending'),
      lastError: Value(null),
    ));
    if (updated > 0) _kick();
  }

  /// Drops every queued operation for [clientId] without sending anything.
  /// The local row (if any) is left as-is — it simply stays a purely local,
  /// never-synced entity rather than being retried forever or silently
  /// deleted out from under the user.
  Future<void> discard(String clientId) async {
    await (_db.delete(_db.pendingOperations)..where((t) => t.clientId.equals(clientId))).go();
  }

  Future<bool> _hasPendingOperation(String clientId, String operation) async {
    final row = await (_db.select(_db.pendingOperations)
          ..where((t) => t.clientId.equals(clientId) & t.operation.equals(operation)))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> _insert({
    required String clientId,
    required String entityType,
    required String operation,
    required Map<String, dynamic> payload,
    String? dependsOnClientId,
  }) {
    return _db.into(_db.pendingOperations).insert(PendingOperationsCompanion.insert(
          clientId: clientId,
          entityType: entityType,
          operation: operation,
          payloadJson: jsonEncode(payload),
          dependsOnClientId: Value(dependsOnClientId),
          createdAt: DateTime.now(),
        ));
  }

  /// Fire-and-forget: the caller's local write already landed, so the UI
  /// doesn't wait on this — the sync (and any retry) happens in the background.
  void _kick() => unawaited(_syncEngine.sync());
}

final outboxWriterProvider = Provider<OutboxWriter>((ref) {
  return OutboxWriter(ref.watch(appDatabaseProvider), ref.watch(syncEngineProvider));
});
