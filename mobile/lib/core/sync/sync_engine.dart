import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../local_db/app_database.dart';
import 'client_ref.dart';
import 'entity_sync_config.dart';

/// Drains the `pending_operations` outbox: sends each queued create/update/
/// delete to the backend, in dependency order, and reconciles local state
/// (serverId, deletes) on success.
///
/// Call [sync] whenever connectivity returns, the app resumes, or on a
/// lightweight foreground timer. Safe to call repeatedly — concurrent calls
/// are coalesced via [_running].
class SyncEngine {
  SyncEngine(this._db, this._dio);

  final AppDatabase _db;
  final Dio _dio;

  bool _running = false;

  Future<void> sync() async {
    if (_running) return;
    _running = true;
    try {
      // Keep draining until a full pass makes no progress: a row blocked on
      // a dependency earlier in the same pass can become processable once
      // that dependency succeeds later in the same pass.
      var madeProgress = true;
      while (madeProgress) {
        madeProgress = await _runOnePass();
      }
    } finally {
      _running = false;
    }
  }

  Future<bool> _runOnePass() async {
    // Network-failed rows are eligible again automatically (marked with the
    // "[network] " prefix below); other failures stay parked in `failed`
    // until something other than this engine resolves them.
    final candidates = await (_db.select(_db.pendingOperations)
          ..where((t) =>
              t.status.equals('pending') |
              (t.status.equals('failed') & t.lastError.like('[network] %')))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();

    var progressed = false;
    for (final op in candidates) {
      if (await _isBlocked(op)) continue;
      if (await _process(op)) progressed = true;
    }
    return progressed;
  }

  /// True while [op] still depends on another operation that hasn't synced.
  /// Covers two cases: the explicit single-parent [dependsOnClientId] (e.g. a
  /// water entry waiting on its source), and any number of `clientRef:`
  /// markers embedded in the payload itself (e.g. a workout template
  /// referencing several not-yet-synced exercises) — the latter is checked
  /// generically so payloads with multiple/nested references don't need a
  /// dedicated dependency column.
  Future<bool> _isBlocked(PendingOperationRow op) async {
    final dependsOn = op.dependsOnClientId;
    if (dependsOn != null && await _hasPendingOperation(dependsOn)) {
      return true;
    }
    return _hasUnresolvedRefs(jsonDecode(op.payloadJson));
  }

  Future<bool> _hasPendingOperation(String clientId) async {
    final row = await (_db.select(_db.pendingOperations)..where((t) => t.clientId.equals(clientId)))
        .getSingleOrNull();
    return row != null;
  }

  /// Recursively scans a decoded payload for `clientRef:` markers and
  /// reports whether any of them still has a sync in flight. A marker whose
  /// target has neither a serverId nor a pending operation is a dangling
  /// reference (e.g. the referenced row was deleted before it ever synced)
  /// rather than something to wait for — that's left for [_resolvePayload]
  /// to reject so the operation is parked as failed instead of blocked
  /// forever.
  Future<bool> _hasUnresolvedRefs(Object? value) async {
    if (value is Map) {
      for (final v in value.values) {
        if (await _hasUnresolvedRefs(v)) return true;
      }
      return false;
    }
    if (value is List) {
      for (final item in value) {
        if (await _hasUnresolvedRefs(item)) return true;
      }
      return false;
    }
    if (isClientRef(value)) {
      final clientId = clientRefId(value as String);
      if (await _lookupServerId(null, clientId) != null) return false;
      return _hasPendingOperation(clientId);
    }
    return false;
  }

  Future<bool> _process(PendingOperationRow op) async {
    await (_db.update(_db.pendingOperations)..where((t) => t.id.equals(op.id)))
        .write(const PendingOperationsCompanion(status: Value('syncing')));

    final config = entitySyncConfigs[op.entityType];
    if (config == null) {
      await _markFailed(op, 'Unknown entity type: ${op.entityType}', isNetworkError: false);
      return false;
    }

    try {
      final payload =
          await _resolvePayload(jsonDecode(op.payloadJson)) as Map<String, dynamic>;
      final response = await _send(op, config, payload);
      await _applySuccess(op, config, response);
      await _db.delete(_db.pendingOperations).delete(op);
      return true;
    } on DioException catch (e) {
      // No response at all (timeout/connection error/DNS failure, etc.) is
      // the connectivity case; anything with a response is a real backend
      // answer (4xx/5xx) and won't fix itself by retrying blindly.
      await _markFailed(op, _describeError(e), isNetworkError: e.response == null);
      return false;
    } catch (e) {
      await _markFailed(op, e.toString(), isNetworkError: false);
      return false;
    }
  }

  Future<Response<dynamic>> _send(
    PendingOperationRow op,
    EntitySyncConfig config,
    Map<String, dynamic> payload,
  ) async {
    if (config.isSingleton) {
      return _dio.put<dynamic>(config.basePath, data: payload);
    }
    switch (op.operation) {
      case 'create':
        return _dio.post<dynamic>(config.basePath, data: payload);
      case 'update':
        final serverId = await _requireServerId(config, op.clientId);
        return _dio.put<dynamic>('${config.basePath}/$serverId', data: payload);
      case 'delete':
        final serverId = await _requireServerId(config, op.clientId);
        return _dio.delete<dynamic>('${config.basePath}/$serverId');
      default:
        throw StateError('Unknown operation: ${op.operation}');
    }
  }

  Future<void> _applySuccess(
    PendingOperationRow op,
    EntitySyncConfig config,
    Response<dynamic> response,
  ) async {
    switch (op.operation) {
      case 'create':
        final data = response.data;
        if (data is Map && data['id'] != null) {
          await _db.customStatement(
            'UPDATE ${config.tableName} SET server_id = ? WHERE client_id = ?',
            [(data['id'] as num).toInt(), op.clientId],
          );
        }
      case 'delete':
        await _db.customStatement(
          'DELETE FROM ${config.tableName} WHERE client_id = ?',
          [op.clientId],
        );
      case 'update':
        break; // the local row already holds the latest data
    }
  }

  /// An update/delete should only ever be queued for an entity whose create
  /// has already synced — if not (e.g. the create is still pending in the
  /// same batch), this throws and the operation is parked as failed rather
  /// than silently hitting a nonexistent backend id.
  Future<int> _requireServerId(EntitySyncConfig config, String clientId) async {
    final serverId = await _lookupServerId(config.tableName, clientId);
    if (serverId == null) {
      throw StateError(
          'No serverId yet for $clientId in ${config.tableName} — is dependsOnClientId set?');
    }
    return serverId;
  }

  /// Walks the decoded payload and replaces every `clientRef:<uuid>` marker
  /// with the referenced entity's serverId.
  Future<Object?> _resolvePayload(Object? value) async {
    if (value is Map<String, dynamic>) {
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        result[entry.key] = await _resolvePayload(entry.value);
      }
      return result;
    }
    if (value is List) {
      final result = [];
      for (final item in value) {
        result.add(await _resolvePayload(item));
      }
      return result;
    }
    if (isClientRef(value)) {
      final clientId = clientRefId(value as String);
      final serverId = await _lookupServerId(null, clientId);
      if (serverId == null) {
        throw StateError('Unresolved clientRef: $clientId — is dependsOnClientId set?');
      }
      return serverId;
    }
    return value;
  }

  /// Looks up a serverId by clientId. If [tableName] is given, only that
  /// table is checked; otherwise every known entity table is checked in
  /// turn (safe, since clientIds are UUIDs unique across all tables).
  Future<int?> _lookupServerId(String? tableName, String clientId) async {
    for (final table in tableName != null ? [tableName] : allEntityTableNames) {
      final row = await _db
          .customSelect(
            'SELECT server_id FROM $table WHERE client_id = ?',
            variables: [Variable.withString(clientId)],
          )
          .getSingleOrNull();
      if (row != null) return row.read<int?>('server_id');
    }
    return null;
  }

  Future<void> _markFailed(PendingOperationRow op, String message,
      {required bool isNetworkError}) async {
    final prefixed = isNetworkError ? '[network] $message' : message;
    await (_db.update(_db.pendingOperations)..where((t) => t.id.equals(op.id))).write(
      PendingOperationsCompanion(status: const Value('failed'), lastError: Value(prefixed)),
    );
  }

  String _describeError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return e.message ?? e.toString();
  }
}
