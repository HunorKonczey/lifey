import 'package:google_mobile_ads/google_mobile_ads.dart';

/// The subset of [AdSize]/[BannerAd] a real device call actually needs —
/// [AdSize.getLargeAnchoredAdaptiveBannerAdSize] is a static platform-channel
/// call and [BannerAd.load] fires one too, so neither can be faked by
/// overriding a constructible object directly. Same seam as [AdsClient]/
/// [ConsentClient] (`67` Prompt 8) for the identical reason: tests inject a
/// fake that invokes the listener callbacks synchronously instead of
/// touching a platform channel.
abstract class BannerAdLoader {
  Future<AnchoredAdaptiveBannerAdSize?> getAdaptiveSize(int width);

  /// Constructs and loads a banner ad, returning it immediately — the load
  /// result arrives later through [listener]. Never throws.
  BannerAd load({
    required String adUnitId,
    required AdSize size,
    required AdRequest request,
    required BannerAdListener listener,
  });
}

/// Delegates straight to the real [AdSize]/[BannerAd] APIs.
class PlatformBannerAdLoader implements BannerAdLoader {
  @override
  Future<AnchoredAdaptiveBannerAdSize?> getAdaptiveSize(int width) =>
      AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);

  @override
  BannerAd load({
    required String adUnitId,
    required AdSize size,
    required AdRequest request,
    required BannerAdListener listener,
  }) {
    final ad = BannerAd(adUnitId: adUnitId, size: size, request: request, listener: listener);
    ad.load();
    return ad;
  }
}
