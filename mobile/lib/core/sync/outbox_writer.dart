import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local_db/app_database.dart';
import '../local_db/database_provider.dart';
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
  Future<void> enqueueDelete({required String clientId, required String entityType}) async {
    final createPending = await _hasPendingOperation(clientId, 'create');
    await (_db.delete(_db.pendingOperations)..where((t) => t.clientId.equals(clientId))).go();
    if (createPending) return;

    await _insert(clientId: clientId, entityType: entityType, operation: 'delete', payload: const {});
    _kick();
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
