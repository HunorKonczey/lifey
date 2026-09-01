import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'entitlement.dart';
import 'entitlement_repository.dart';

/// Streams the resolved entitlement (D-P4) — the single source every gate
/// and every derived provider below reads from. Wraps
/// [EntitlementRepository.watch], the same "`StreamNotifier` wrapping a
/// repository's watch stream" shape as every other feature controller.
class EntitlementController extends StreamNotifier<Entitlement> {
  EntitlementRepository get _repo => ref.read(entitlementRepositoryProvider);

  @override
  Stream<Entitlement> build() => _repo.watch();
}

final entitlementProvider =
    StreamNotifierProvider<EntitlementController, Entitlement>(EntitlementController.new);

/// UI copy only (D-P5) — e.g. the Settings tile headline. No gate reads this;
/// every gate below reads a *field* instead.
final isProProvider = Provider<bool>((ref) {
  return ref.watch(entitlementProvider).value?.tier == EntitlementTier.pro;
});

/// Defaults to `false` (no ads) while the entitlement stream is still
/// loading, same as an unresolved snapshot — the ad slot must never flash an
/// ad before the real answer arrives (`63` §8.6).
final adsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(entitlementProvider).value?.adsEnabled ?? false;
});

/// `null` means no cutoff (show everything) — both while unresolved/loading
/// (open, D-P4) and for an unlimited Pro snapshot (`67` §3.2). This is a
/// presentation filter only (D-P6): it must never be used to limit what sync
/// fetches or stores.
final historyCutoffProvider = Provider<DateTime?>((ref) {
  final historyDays = ref.watch(entitlementProvider).value?.historyDays;
  if (historyDays == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: historyDays));
});

/// `null` means unlimited — both while unresolved/loading (open, D-P4) and
/// for Pro.
final aiCreditsProvider = Provider<int?>((ref) {
  return ref.watch(entitlementProvider).value?.aiCreditsRemaining;
});
