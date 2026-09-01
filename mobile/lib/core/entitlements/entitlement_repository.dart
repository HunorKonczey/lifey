import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_endpoints.dart';
import '../local_db/app_database.dart';
import '../local_db/database_provider.dart';
import '../network/dio_client.dart';
import 'entitlement.dart';

/// Server-truth cache for the current user's billing entitlement
/// (`GET /api/v1/me/entitlements`, `64` §3) — one Drift row
/// ([EntitlementCacheTable]), written only here, never through
/// `OutboxWriter`/`SyncEngine` (D-P2).
///
/// This class owns *what* the resolved entitlement is right now (D-P4);
/// *when* to call [refresh] — app start, foreground after 15 minutes, after
/// a purchase/restore, after a trainer-invite transition, on a `402`/`403`
/// — is `EntitlementRefresher`'s job (`67` Prompt 2, D-P3).
class EntitlementRepository {
  EntitlementRepository(this._db, this._dio);

  final AppDatabase _db;
  final Dio _dio;

  static const _rowId = 'singleton';

  /// GETs the current entitlement and, on success, overwrites the cache.
  /// Never throws (D-M9: a lookup failure must never surface as an error to
  /// the caller) — [watch]/[current] keep resolving from whatever is already
  /// cached. Returns whether the fetch succeeded, for callers that want to
  /// log or retry.
  Future<bool> refresh() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.entitlements);
      final entitlement = Entitlement.fromJson(response.data!);
      await _writeCache(entitlement);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The entitlement to gate on right now — D-P4's ladder, re-applied
  /// against the wall clock on every emission (not just at fetch time), so a
  /// session that stays open past `graceUntil` still sees the decay without
  /// needing a new network round trip.
  Stream<Entitlement> watch() {
    return (_db.select(_db.entitlementCacheTable)..where((t) => t.id.equals(_rowId)))
        .watchSingleOrNull()
        .map(_resolve);
  }

  Future<Entitlement> current() async {
    final row = await (_db.select(_db.entitlementCacheTable)..where((t) => t.id.equals(_rowId)))
        .getSingleOrNull();
    return _resolve(row);
  }

  Entitlement _resolve(EntitlementCacheRow? row) {
    if (row == null) return Entitlement.unresolvedOpen();
    final cached = _fromRow(row);
    if (DateTime.now().isBefore(cached.graceUntil)) return cached;
    return Entitlement.decayedToFree(checkedAt: cached.checkedAt, graceUntil: cached.graceUntil);
  }

  Future<void> _writeCache(Entitlement e) async {
    await _db.into(_db.entitlementCacheTable).insertOnConflictUpdate(
          EntitlementCacheTableCompanion(
            id: const Value(_rowId),
            tier: Value(e.tier.name.toUpperCase()),
            source: Value(e.source.wireName),
            adsEnabled: Value(e.adsEnabled),
            historyDays: Value(e.historyDays),
            aiCreditsRemaining: Value(e.aiCreditsRemaining),
            trainerPlan: Value(e.trainer?.plan),
            trainerStatus: Value(e.trainer?.status),
            trainerMaxClients: Value(e.trainer?.maxClients),
            trainerActiveClients: Value(e.trainer?.activeClients),
            trainerTrialEndsAt: Value(e.trainer?.trialEndsAt),
            expiresAt: Value(e.expiresAt),
            checkedAt: Value(e.checkedAt),
            graceUntil: Value(e.graceUntil),
            degraded: Value(e.degraded),
          ),
        );
  }

  Entitlement _fromRow(EntitlementCacheRow row) {
    return Entitlement(
      tier: row.tier.toUpperCase() == 'PRO' ? EntitlementTier.pro : EntitlementTier.free,
      source: EntitlementSource.fromWire(row.source),
      adsEnabled: row.adsEnabled,
      historyDays: row.historyDays,
      aiCreditsRemaining: row.aiCreditsRemaining,
      trainer: row.trainerPlan == null
          ? null
          : TrainerBillingEntitlement(
              plan: row.trainerPlan!,
              status: row.trainerStatus!,
              maxClients: row.trainerMaxClients!,
              activeClients: row.trainerActiveClients!,
              trialEndsAt: row.trainerTrialEndsAt,
            ),
      expiresAt: row.expiresAt,
      checkedAt: row.checkedAt,
      graceUntil: row.graceUntil,
      degraded: row.degraded,
      resolved: true,
    );
  }
}

final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  return EntitlementRepository(ref.watch(appDatabaseProvider), ref.watch(dioClientProvider));
});
