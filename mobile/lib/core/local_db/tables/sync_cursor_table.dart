import 'package:drift/drift.dart';

/// Per-entity delta-sync cursor (see docs/15-delta-sync.md): the newest
/// `updatedAt` observed in the last successful delta pull for that entity,
/// minus the overlap window. Absence of a row for an entity means it has
/// never been delta-synced yet — [PullEngine] takes the full-pull bootstrap
/// path until the first successful pull seeds one.
class SyncCursors extends Table {
  @override
  String get tableName => 'sync_cursors';

  TextColumn get entityType => text()();
  DateTimeColumn get lastSyncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {entityType};
}
