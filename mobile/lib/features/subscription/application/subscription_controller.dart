import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/entitlements/entitlement_refresher.dart';
import '../data/purchase_repository.dart';
import '../domain/purchase_result.dart';
import '../domain/subscription_product.dart';

/// The store's own products (`67` §4.1 step 1) — queried once per paywall
/// visit. `AsyncValue.loading` is what drives the plan-card skeletons
/// (`69` §12.8); an empty list (not an error) is also possible and means
/// the same thing to the UI — "temporarily unavailable", never a fabricated
/// price.
final subscriptionProductsProvider = FutureProvider<List<SubscriptionProduct>>((ref) {
  return ref.watch(purchaseRepositoryProvider).queryProducts();
});

/// The plan currently highlighted in the two-card selector. Yearly
/// pre-selected (`69` §3.1) — in-memory only, resets every time the paywall
/// is reopened.
class SelectedSubscriptionProductController extends Notifier<String> {
  @override
  String build() => yearlySubscriptionProductId;

  void select(String productId) => state = productId;
}

final selectedSubscriptionProductIdProvider =
    NotifierProvider<SelectedSubscriptionProductController, String>(
  SelectedSubscriptionProductController.new,
);

/// Which product [SubscriptionController.buy] is currently in flight for
/// (`null` when none), plus the most recent terminal [PurchaseOutcome] for
/// the paywall to react to (success/failure feedback, D-P8's pending state).
class PurchaseFlowState {
  const PurchaseFlowState({this.purchasingProductId, this.lastOutcome});

  final String? purchasingProductId;
  final PurchaseOutcome? lastOutcome;
}

/// Drives the purchase flow (`67` §4.1): subscribes to
/// [PurchaseRepository.watchPurchases] once for the controller's lifetime,
/// refreshes entitlements on a result that changes billing state, and
/// exposes [buy]/[restore] for the paywall screen.
class SubscriptionController extends Notifier<PurchaseFlowState> {
  PurchaseRepository get _repo => ref.read(purchaseRepositoryProvider);

  StreamSubscription<PurchaseResult>? _subscription;

  @override
  PurchaseFlowState build() {
    _subscription = _repo.watchPurchases().listen(_onResult);
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
    });
    return const PurchaseFlowState();
  }

  void _onResult(PurchaseResult result) {
    // D-P3: "immediately after a successful purchase or restore" — a
    // terminal rejection also means the server's view of this user's
    // billing may have changed (e.g. now linked to a different account),
    // so it refreshes too.
    if (result.outcome == PurchaseOutcome.success ||
        result.outcome == PurchaseOutcome.terminalRejection) {
      unawaited(ref.read(entitlementRefresherProvider).refreshNow());
    }
    state = PurchaseFlowState(
      // A pending purchase is still "in flight" from the UI's perspective;
      // every other outcome is terminal and clears the spinner.
      purchasingProductId: result.outcome == PurchaseOutcome.pending ? result.productId : null,
      lastOutcome: result.outcome,
    );
  }

  /// Starts the purchase flow for [productId]. The actual result arrives
  /// later through [state] via [_onResult], once the store/backend round
  /// trip completes.
  Future<void> buy(String productId) async {
    state = PurchaseFlowState(purchasingProductId: productId, lastOutcome: null);
    final sent = await _repo.buy(productId);
    if (!sent) {
      state = const PurchaseFlowState(purchasingProductId: null, lastOutcome: PurchaseOutcome.failed);
    }
  }

  Future<void> restore() => _repo.restore();
}

final subscriptionControllerProvider =
    NotifierProvider<SubscriptionController, PurchaseFlowState>(SubscriptionController.new);
