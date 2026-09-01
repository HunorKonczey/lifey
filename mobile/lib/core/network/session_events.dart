import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fired by [AuthInterceptor] when a token refresh fails, so the auth feature
/// can clear its signed-in state without core/network code depending on it.
class SessionExpiredNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void notify() => state++;
}

final sessionExpiredProvider =
    NotifierProvider<SessionExpiredNotifier, int>(SessionExpiredNotifier.new);

/// Fired by [GateRejectionInterceptor] on a 402/403 from any gated endpoint
/// (`docs/landing_page/67-mobile-free-pro-plan.md` D-P3), so `core/network`
/// never has to import `core/entitlements` — `EntitlementRefresher` is the
/// listener.
class GateRejectionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void notify() => state++;
}

final gateRejectionProvider =
    NotifierProvider<GateRejectionNotifier, int>(GateRejectionNotifier.new);
