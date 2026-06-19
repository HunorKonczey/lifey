import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local_db/database_provider.dart';
import '../network/dio_client.dart';
import 'sync_engine.dart';

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(ref.watch(appDatabaseProvider), ref.watch(dioClientProvider));
});
