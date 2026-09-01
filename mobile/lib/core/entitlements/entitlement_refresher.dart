import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/session_events.dart';
import 'entitlement_repository.dart';

/// Decides *when* [EntitlementRepository.refresh] runs — D-P3's five points,
/// and only these:
/// - app start after auth (called explicitly from `AuthController`)
/// - app resume, but only once the cache is stale (handled internally below)
/// - immediately after a successful purchase or restore (`67` Prompt 5/6)
/// - after accepting or losing a trainer invite, a D-M4 sponsorship
///   transition (called from `TrainerInviteController`/`MyTrainersController`)
/// - on a 402/403 from any gated endpoint, via [gateRejectionProvider] so
///   `core/network` never has to import `core/entitlements`
///
/// Never a timer, never on every screen build.
///
/// Watched once at app root (`LifeyApp`), same as `ConnectivitySyncController`
/// — kept alive for the app's lifetime purely to hold the app-lifecycle
/// observer and the [gateRejectionProvider] listener below. [refreshNow] is
/// what every other trigger calls directly.
class EntitlementRefresher with WidgetsBindingObserver {
  EntitlementRefresher(this._ref, this._repo) {
    WidgetsBinding.instance.addObserver(this);
    _ref.listen(gateRejectionProvider, (previous, next) => unawaited(refreshNow()));
  }

  /// App resume only refreshes once the cache is old enough that the round
  /// trip is worth it (D-P3) — an unresolved (never-cached) entitlement
  /// counts as stale too, so a resume shortly after a failed cold-start
  /// fetch gets another chance.
  static const _resumeStaleAfter = Duration(minutes: 15);

  final Ref _ref;
  final EntitlementRepository _repo;

  /// Unconditional refresh — every trigger except app-resume calls this
  /// directly.
  Future<void> refreshNow() => _repo.refresh();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshIfStale());
    }
  }

  Future<void> _refreshIfStale() async {
    final current = await _repo.current();
    final stale = !current.resolved ||
        DateTime.now().difference(current.checkedAt) >= _resumeStaleAfter;
    if (stale) await refreshNow();
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);
}

final entitlementRefresherProvider = Provider<EntitlementRefresher>((ref) {
  final refresher = EntitlementRefresher(ref, ref.watch(entitlementRepositoryProvider));
  ref.onDispose(refresher.dispose);
  return refresher;
});
