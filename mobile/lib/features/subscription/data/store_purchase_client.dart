import 'package:in_app_purchase/in_app_purchase.dart';

/// The subset of [InAppPurchase] [PurchaseRepository] needs. [InAppPurchase]
/// itself has a private constructor and can't be subclassed or mocked
/// directly, so tests substitute [StorePurchaseClient] instead (`67`
/// Prompt 5's own verify line: "unit tests with a fake `InAppPurchase`").
abstract class StorePurchaseClient {
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> completePurchase(PurchaseDetails purchase);
  Future<void> restorePurchases();
}

/// Delegates straight to [InAppPurchase.instance].
class PlatformStorePurchaseClient implements StorePurchaseClient {
  final InAppPurchase _iap = InAppPurchase.instance;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _iap.queryProductDetails(identifiers);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _iap.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> completePurchase(PurchaseDetails purchase) => _iap.completePurchase(purchase);

  @override
  Future<void> restorePurchases() => _iap.restorePurchases();
}
