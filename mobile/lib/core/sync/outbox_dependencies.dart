import 'dart:convert';

import '../local_db/app_database.dart';
import 'client_ref.dart';

/// The clientIds [op] waits for: its explicit single parent
/// ([PendingOperationRow.dependsOnClientId]) plus every `clientRef:` marker
/// anywhere in its payload — the same two sources `SyncEngine._isBlocked`
/// holds an operation back on. An operation's own clientId is not a
/// dependency (an update queued behind its own create names itself).
Set<String> outboxDependencies(PendingOperationRow op) {
  final result = <String>{};
  final parent = op.dependsOnClientId;
  if (parent != null) result.add(parent);
  _collectRefs(jsonDecode(op.payloadJson), result);
  result.remove(op.clientId);
  return result;
}

void _collectRefs(Object? value, Set<String> into) {
  if (value is Map) {
    for (final v in value.values) {
      _collectRefs(v, into);
    }
  } else if (value is List) {
    for (final item in value) {
      _collectRefs(item, into);
    }
  } else if (isClientRef(value)) {
    into.add(clientRefId(value as String));
  }
}

/// Whether [op] failed for a reason a later pass will not fix by itself.
/// Network failures (`[network] ` prefix) are retried automatically.
bool isPermanentlyFailed(PendingOperationRow op) =>
    op.status == 'failed' && !(op.lastError?.startsWith('[network] ') ?? false);

/// Maps every clientId that is stuck behind a permanently failed create to the
/// error of the failure it is stuck behind (followed transitively: a meal
/// waiting on a food that waits on nothing but is itself waiting for a failed
/// exercise is stuck too). A clientId whose own operation failed is not in the
/// map — its own status already says so.
Map<String, String?> blockedByFailure(List<PendingOperationRow> ops) {
  // clientId -> error of the failed create at the root of the blockage.
  final broken = <String, String?>{
    for (final op in ops)
      if (op.operation == 'create' && isPermanentlyFailed(op)) op.clientId: op.lastError,
  };
  final blocked = <String, String?>{};
  var changed = true;
  while (changed) {
    changed = false;
    for (final op in ops) {
      if (isPermanentlyFailed(op) || blocked.containsKey(op.clientId)) continue;
      for (final dependency in outboxDependencies(op)) {
        final isBroken = broken.containsKey(dependency);
        if (isBroken || blocked.containsKey(dependency)) {
          blocked[op.clientId] = isBroken ? broken[dependency] : blocked[dependency];
          changed = true;
          break;
        }
      }
    }
  }
  return blocked;
}

/// Every clientId [clientId]'s queued operations depend on, directly or not.
Set<String> outboxAncestors(String clientId, List<PendingOperationRow> ops) {
  final seen = <String>{};
  final queue = <String>[clientId];
  while (queue.isNotEmpty) {
    final current = queue.removeLast();
    for (final op in ops.where((o) => o.clientId == current)) {
      for (final dependency in outboxDependencies(op)) {
        if (seen.add(dependency)) queue.add(dependency);
      }
    }
  }
  seen.remove(clientId);
  return seen;
}
