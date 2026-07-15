import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local_db/database_provider.dart';
import '../network/dio_client.dart';
import 'sync_engine.dart';
import 'sync_lock.dart';

/// Shared with [pullEngineProvider] so [SyncEngine.sync] and
/// [PullEngine.pullAll] serialize against each other — see [SyncLock].
final syncLockProvider = Provider<SyncLock>((ref) => SyncLock());

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    ref.watch(appDatabaseProvider),
    ref.watch(dioClientProvider),
    ref.watch(syncLockProvider),
  );
});
