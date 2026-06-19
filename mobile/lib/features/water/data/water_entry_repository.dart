import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/local_db/database_provider.dart';
import '../../../core/sync/client_id.dart';
import '../../../core/sync/client_ref.dart';
import '../../../core/sync/outbox_writer.dart';

/// Local-first access to logging water intake. There's no list/edit UI for
/// past entries (only the dashboard's aggregate total, via `/statistics`),
/// so this only needs to support creating one.
class WaterEntryRepository {
  WaterEntryRepository(this._db, this._outbox);

  final AppDatabase _db;
  final OutboxWriter _outbox;

  Future<void> create({
    required DateTime consumedAt,
    String? sourceClientId,
    required double volumeLiters,
  }) async {
    final clientId = newClientId();
    await _db.into(_db.waterEntries).insert(WaterEntriesCompanion.insert(
          clientId: clientId,
          sourceClientId: Value(sourceClientId),
          volumeLiters: volumeLiters,
          consumedAt: consumedAt,
        ));
    await _outbox.enqueueCreate(
      clientId: clientId,
      entityType: 'water_entry',
      payload: {
        'consumedAt': consumedAt.toUtc().toIso8601String(),
        'volumeLiters': volumeLiters,
        if (sourceClientId != null) 'sourceId': clientRef(sourceClientId),
      },
      // Waits for the source's own create to sync first, if it hasn't yet —
      // harmless (resolves immediately) when the source already has synced.
      dependsOnClientId: sourceClientId,
    );
  }
}

final waterEntryRepositoryProvider = Provider<WaterEntryRepository>((ref) {
  return WaterEntryRepository(ref.watch(appDatabaseProvider), ref.watch(outboxWriterProvider));
});
