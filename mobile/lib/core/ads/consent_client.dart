import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// The subset of the UMP SDK [ConsentManager] needs, wrapped as `Future`s
/// instead of the SDK's callback style, and behind an interface so tests can
/// substitute a fake — [ConsentInformation.instance] is a mutable static
/// field (easy to swap on its own), but [ConsentForm]'s methods are plain
/// statics with no override seam, so this wraps both under one fakeable
/// surface (same reasoning as [AdsClient] for [MobileAds]).
abstract class ConsentClient {
  Future<void> requestConsentInfoUpdate(ConsentRequestParameters params);
  Future<bool> isConsentFormAvailable();
  Future<ConsentStatus> getConsentStatus();

  /// Loads and shows a consent form only if one is required. Completes with
  /// a [FormError] if loading or showing failed, or `null` on success
  /// (including "no form was required," which isn't an error).
  Future<FormError?> loadAndShowConsentFormIfRequired();
}

class PlatformConsentClient implements ConsentClient {
  @override
  Future<void> requestConsentInfoUpdate(ConsentRequestParameters params) {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      completer.complete,
      (error) => completer.completeError(error),
    );
    return completer.future;
  }

  @override
  Future<bool> isConsentFormAvailable() => ConsentInformation.instance.isConsentFormAvailable();

  @override
  Future<ConsentStatus> getConsentStatus() => ConsentInformation.instance.getConsentStatus();

  @override
  Future<FormError?> loadAndShowConsentFormIfRequired() {
    final completer = Completer<FormError?>();
    ConsentForm.loadAndShowConsentFormIfRequired(completer.complete);
    return completer.future;
  }
}
