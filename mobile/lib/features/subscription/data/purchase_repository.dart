import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../domain/purchase_result.dart';
import '../domain/subscription_product.dart';
import 'store_purchase_client.dart';

/// StoreKit 2 (iOS) / Play Billing (Android) purchase flow for Lifey Pro
/// (`docs/landing_page/67-mobile-free-pro-plan.md` §4.1). Online-only, no
/// Drift/outbox involvement — the store and the backend are the only two
/// sources of truth here; the result is a refreshed entitlement, not a row
/// this repository owns.
///
/// Callers (`SubscriptionController`, Prompt 6): refresh entitlements
/// (`entitlementRefresherProvider.refreshNow()`) on [PurchaseOutcome.success]
/// and [PurchaseOutcome.terminalRejection] alike — D-P3 says "after a
/// successful purchase or restore", and a terminal rejection still means the
/// server's view of this user's billing state may have changed (e.g. it's
/// now linked to a different account).
class PurchaseRepository {
  PurchaseRepository(this._client, this._dio);

  final StorePurchaseClient _client;
  final Dio _dio;

  /// Populated by [queryProducts] — [buy] needs the store's own
  /// [ProductDetails] object back, not just its id: [PurchaseParam] requires
  /// the exact object the store returned (`67` §4.1 — prices are never
  /// reconstructed from a constant, so there is no other way to get one).
  final _productDetailsById = <String, ProductDetails>{};

  Future<bool> isAvailable() => _client.isAvailable();

  /// Queries the store for [subscriptionProductIds]. Returns whatever the
  /// store had — possibly fewer than requested, possibly empty; a caller
  /// (the paywall, Prompt 6) shows the "temporarily unavailable" state on an
  /// empty result rather than this repository guessing at a fallback.
  Future<List<SubscriptionProduct>> queryProducts() async {
    final response = await _client.queryProductDetails(subscriptionProductIds);
    _productDetailsById
      ..clear()
      ..addEntries(response.productDetails.map((d) => MapEntry(d.id, d)));
    return response.productDetails.map(_toSubscriptionProduct).toList();
  }

  SubscriptionProduct _toSubscriptionProduct(ProductDetails details) {
    return SubscriptionProduct(
      id: details.id,
      period: details.id == yearlySubscriptionProductId
          ? SubscriptionPeriod.yearly
          : SubscriptionPeriod.monthly,
      formattedPrice: details.price,
      rawPrice: details.rawPrice,
      currencyCode: details.currencyCode,
    );
  }

  /// Starts the purchase flow for [productId] — must be one returned by a
  /// prior, successful [queryProducts] call. Returns whether the request was
  /// sent; the actual result arrives later on [watchPurchases] (`67` §4.1
  /// step 3 — `buyNonConsumable` never returns the purchase result itself).
  Future<bool> buy(String productId) {
    final details = _productDetailsById[productId];
    if (details == null) {
      throw StateError('queryProducts() must succeed before buy($productId)');
    }
    return _client.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: details));
  }

  /// Triggers `purchaseStream` deliveries for whatever this store account
  /// already owns, each with [PurchaseStatus.restored] — handled by
  /// [watchPurchases] exactly like a fresh purchase (`67` §4.2).
  Future<void> restore() => _client.restorePurchases();

  /// One [PurchaseResult] per `purchaseStream` update, verified and
  /// completed per D-P8. Subscribe once, early (e.g.
  /// `SubscriptionController.build()`, Prompt 6) — [InAppPurchase]'s own
  /// contract requires listening from app start or an update from the
  /// previous session is missed.
  Stream<PurchaseResult> watchPurchases() {
    return _client.purchaseStream
        .asyncExpand((batch) => Stream.fromIterable(batch))
        .asyncMap((purchase) async {
      final outcome = await _handle(purchase);
      return PurchaseResult(productId: purchase.productID, outcome: outcome);
    });
  }

  Future<PurchaseOutcome> _handle(PurchaseDetails purchase) {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        return Future.value(PurchaseOutcome.pending);
      case PurchaseStatus.canceled:
        return Future.value(PurchaseOutcome.canceled);
      case PurchaseStatus.error:
        return Future.value(PurchaseOutcome.failed);
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        return _verifyAndComplete(purchase);
    }
  }

  /// D-P8: `completePurchase` only after the server responds 200 — a crash
  /// or lost connection between the purchase landing and this call
  /// returning leaves the transaction pending, and the store re-delivers it
  /// on the next launch, where this runs again. The one exception is a
  /// terminal rejection (409/422): completing anyway is what stops the
  /// store from re-delivering a transaction the backend will never accept.
  Future<PurchaseOutcome> _verifyAndComplete(PurchaseDetails purchase) async {
    try {
      await _dio.post<void>(
        ApiEndpoints.storePurchase,
        data: {
          'platform': Platform.isIOS ? 'IOS' : 'ANDROID',
          'productId': purchase.productID,
          'purchaseToken': purchase.verificationData.serverVerificationData,
        },
      );
      if (purchase.pendingCompletePurchase) await _client.completePurchase(purchase);
      return PurchaseOutcome.success;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 409 || statusCode == 422) {
        if (purchase.pendingCompletePurchase) await _client.completePurchase(purchase);
        return PurchaseOutcome.terminalRejection;
      }
      return PurchaseOutcome.verificationFailed;
    }
  }
}

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return PurchaseRepository(PlatformStorePurchaseClient(), ref.watch(dioClientProvider));
});
