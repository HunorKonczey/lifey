/// What happened to one purchase-stream update, after
/// [PurchaseRepository]'s own handling (`67` §4.1, D-P8).
enum PurchaseOutcome {
  /// Still processing on the store's side (e.g. "Ask to Buy") — no action,
  /// just reflect it in the UI.
  pending,

  /// The user backed out of the store's own purchase sheet.
  canceled,

  /// The store itself reported a failure (declined card, etc.) — never a
  /// verification failure, see [verificationFailed].
  failed,

  /// Verified with the backend and completed. A caller should refresh
  /// entitlements now (D-P3: "immediately after a successful purchase or
  /// restore") and show the success state.
  success,

  /// The backend rejected the purchase for a reason that will never
  /// change on retry (`409 SUBSCRIPTION_ALREADY_LINKED`,
  /// `422 INVALID_RECEIPT`) — completed anyway per D-P8, so the store
  /// doesn't keep re-delivering a doomed transaction. Show the rejection
  /// reason, not a generic error.
  terminalRejection,

  /// The backend call itself failed (offline, 5xx, timeout — or the app
  /// died mid-flight). The transaction is deliberately left **not**
  /// completed (D-P8): the store re-delivers it on the next launch, where
  /// this same handling runs again.
  verificationFailed,
}

/// One [PurchaseOutcome] for one product — [PurchaseRepository.watchPurchases]
/// emits one of these per purchase-stream update.
class PurchaseResult {
  const PurchaseResult({required this.productId, required this.outcome});

  final String productId;
  final PurchaseOutcome outcome;
}
