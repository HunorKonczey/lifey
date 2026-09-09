import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'consent_client.dart';

/// The result of one [ConsentManager.requestConsent] run.
class ConsentOutcome {
  const ConsentOutcome({required this.personalizedAdsAllowed});

  /// Whether ad requests may be personalized. `false` whenever consent
  /// wasn't affirmatively obtained, the user is flagged under-16, or the
  /// flow itself failed (offline, SDK error) — non-personalized is always
  /// the safe fallback, never "no ads" (`63` D-M7: that's what Pro is for).
  final bool personalizedAdsAllowed;

  static const nonPersonalized = ConsentOutcome(personalizedAdsAllowed: false);
}

/// Runs the Google UMP consent flow (`docs/landing_page/67-mobile-free-pro-plan.md`
/// §5.1): GDPR/TCF in the EU, ATT on iOS. No custom pre-prompt screen — the
/// SDK's own UI is the whole flow (`69` §4.6).
class ConsentManager {
  ConsentManager(this._client);

  final ConsentClient _client;

  /// Requests a consent info update tagged for [underAge], shows the
  /// consent form if one is required, and reports the resulting
  /// personalization decision. Never throws — a failure here (offline, SDK
  /// error) must never block the app (D-M7); it resolves to the same
  /// non-personalized outcome as an explicit refusal.
  Future<ConsentOutcome> requestConsent({required bool underAge}) async {
    try {
      await _client.requestConsentInfoUpdate(
        ConsentRequestParameters(tagForUnderAgeOfConsent: underAge),
      );
      if (await _client.isConsentFormAvailable()) {
        await _client.loadAndShowConsentFormIfRequired();
      }
      final status = await _client.getConsentStatus();
      final personalizedAdsAllowed = !underAge &&
          (status == ConsentStatus.obtained || status == ConsentStatus.notRequired);
      return ConsentOutcome(personalizedAdsAllowed: personalizedAdsAllowed);
    } catch (_) {
      return ConsentOutcome.nonPersonalized;
    }
  }
}
