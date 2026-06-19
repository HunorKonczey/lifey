import 'package:drift/drift.dart';

/// The offline-write queue ("outbox"). Every local create/update/delete adds
/// a row here; the sync engine drains it in `id` (FIFO) order once a
/// connection is available, resolving [dependsOnClientId] first when it
/// points at an operation that hasn't synced yet (e.g. a recipe ingredient
/// created in the same offline session as the food it references).
///
/// [clientId] and [dependsOnClientId] are deliberately plain text columns,
/// not foreign keys: depending on [entityType] they can point at a row in
/// any of the entity tables, so the relation is resolved by the sync engine
/// rather than enforced by the database.
@DataClassName('PendingOperationRow')
class PendingOperations extends Table {
  @override
  String get tableName => 'pending_operations';

  IntColumn get id => integer().autoIncrement()();

  /// The clientId of the entity this operation targets (in the table named
  /// by [entityType]).
  TextColumn get clientId => text()();

  /// Which top-level entity this operation is for: `weight_entry`, `food`,
  /// `recipe`, `meal`, `exercise`, `workout_template`, `workout_session`,
  /// `water_source`, `water_entry`, or `user_settings` (see
  /// `core/sync/entity_sync_config.dart`). Child/junction data (recipe
  /// ingredients, meal entries, template/session exercises, sets) is
  /// embedded directly in its parent's payload — the backend's own
  /// create/update endpoints expect it nested, so it never gets its own row
  /// here.
  TextColumn get entityType => text()();

  /// create / update / delete.
  TextColumn get operation => text()();

  /// The request body to send once this operation syncs, serialized as
  /// JSON (already shaped like the backend DTO, minus any ids that are
  /// still only clientIds at queue time).
  TextColumn get payloadJson => text()();

  /// Another operation's [clientId] that must sync first (e.g. the parent
  /// entity), or null if this operation has no unresolved dependency.
  TextColumn get dependsOnClientId => text().nullable()();

  /// pending / syncing / failed. Successfully synced operations are deleted
  /// from this table rather than kept around with a "done" status.
  TextColumn get status => text().withDefault(const Constant('pending'))();

  DateTimeColumn get createdAt => dateTime()();

  /// Set when [status] is `failed` — a human-readable reason (e.g. the
  /// backend's validation message), shown to the user so they can fix or
  /// discard the operation rather than have it retried forever.
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
