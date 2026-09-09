import 'package:drift/drift.dart';

/// Single-row cache of the last successfully fetched `EntitlementResponse`
/// (`64` §3.2). Written only by `EntitlementRepository` — never through
/// `OutboxWriter` or `SyncEngine` (D-P2, D-M11): this isn't user-owned data,
/// and it changes from server-side events (a Stripe webhook, a trainer's
/// card failing) that bump no `updated_at` the delta-sync feed would ever
/// observe.
@DataClassName('EntitlementCacheRow')
class EntitlementCacheTable extends Table {
  @override
  String get tableName => 'entitlement_cache';

  TextColumn get id => text()();
  TextColumn get tier => text()(); // FREE / PRO
  TextColumn get source => text()(); // NONE / STRIPE / APP_STORE / ...
  BoolColumn get adsEnabled => boolean()();
  IntColumn get historyDays => integer().nullable()();
  IntColumn get aiCreditsRemaining => integer().nullable()();

  // Flattened `trainer` object — present (non-null `trainerPlan`) only for
  // ROLE_TRAINER responses.
  TextColumn get trainerPlan => text().nullable()();
  TextColumn get trainerStatus => text().nullable()();
  IntColumn get trainerMaxClients => integer().nullable()();
  IntColumn get trainerActiveClients => integer().nullable()();
  DateTimeColumn get trainerTrialEndsAt => dateTime().nullable()();

  DateTimeColumn get expiresAt => dateTime().nullable()();
  DateTimeColumn get checkedAt => dateTime()();
  DateTimeColumn get graceUntil => dateTime()();
  BoolColumn get degraded => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
