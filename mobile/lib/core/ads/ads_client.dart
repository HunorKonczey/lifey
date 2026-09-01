import 'package:google_mobile_ads/google_mobile_ads.dart';

/// The subset of [MobileAds] [AdsService] needs. [MobileAds.instance] has a
/// private constructor and can't be subclassed or mocked directly, so tests
/// substitute [AdsClient] instead — the same seam
/// `features/subscription/data/store_purchase_client.dart` uses for
/// [InAppPurchase] (`67` Prompt 5) for the identical reason.
abstract class AdsClient {
  Future<InitializationStatus> initialize();
  Future<void> updateRequestConfiguration(RequestConfiguration configuration);
}

/// Delegates straight to [MobileAds.instance].
class PlatformAdsClient implements AdsClient {
  @override
  Future<InitializationStatus> initialize() => MobileAds.instance.initialize();

  @override
  Future<void> updateRequestConfiguration(RequestConfiguration configuration) =>
      MobileAds.instance.updateRequestConfiguration(configuration);
}
