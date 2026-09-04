import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// A loaded, showable interstitial ad. Deliberately not [InterstitialAd]
/// itself — that class's constructor is private (only [InterstitialAd.load]'s
/// static factory can produce one), so a fake implementation could never
/// hand one back in a test either. This is a plain interface tests can
/// implement freely instead.
abstract class LoadedInterstitialAd {
  Future<void> show();
}

/// The subset of the real SDK [InterstitialManager] needs — see
/// [LoadedInterstitialAd]'s doc for why the seam sits above [InterstitialAd]
/// rather than wrapping it directly, unlike [BannerAdLoader].
abstract class InterstitialAdLoader {
  /// Loads an interstitial ad, resolving to it once ready — or `null` on a
  /// failed load. Never throws.
  Future<LoadedInterstitialAd?> load(String adUnitId, AdRequest request);
}

class _PlatformLoadedInterstitialAd implements LoadedInterstitialAd {
  _PlatformLoadedInterstitialAd(this._ad);
  final InterstitialAd _ad;

  @override
  Future<void> show() => _ad.show();
}

/// Delegates to the real [InterstitialAd.load].
class PlatformInterstitialAdLoader implements InterstitialAdLoader {
  @override
  Future<LoadedInterstitialAd?> load(String adUnitId, AdRequest request) {
    final completer = Completer<LoadedInterstitialAd?>();
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) completer.complete(_PlatformLoadedInterstitialAd(ad));
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );
    return completer.future;
  }
}
