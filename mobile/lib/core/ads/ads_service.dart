import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../entitlements/entitlement_providers.dart';
import '../../features/onboarding/data/user_details_repository.dart';
import '../../features/onboarding/domain/user_details.dart';
import 'ads_client.dart';
import 'consent_client.dart';
import 'consent_manager.dart';

/// Runs the UMP consent flow, applies the resulting age/personalization
/// signal to [RequestConfiguration], then initializes the AdMob SDK
/// (`docs/landing_page/67-mobile-free-pro-plan.md` §5.1). No ad is
/// requested or displayed here — that's `banner_ad_slot.dart`/
/// `interstitial_manager.dart` (Prompt 9/10), which read
/// [personalizedAdsAllowed] once this has run.
class AdsService {
  AdsService(this._client, this._consentManager);

  final AdsClient _client;
  final ConsentManager _consentManager;

  Future<void>? _initialization;
  bool _personalizedAdsAllowed = false;

  /// Whether ad requests may be personalized — `false` (the safe default)
  /// until [ensureInitialized] has actually resolved.
  bool get personalizedAdsAllowed => _personalizedAdsAllowed;

  /// Call only once the entitlement has resolved and `adsEnabled` is true —
  /// a Pro user must never see a consent dialog for ads they'll never be
  /// shown (`67` §5.1). Idempotent: concurrent/repeat calls all await the
  /// same run. Never throws (D-M7: never a blocking wall).
  Future<void> ensureInitialized({required bool underAge}) {
    return _initialization ??= _run(underAge: underAge);
  }

  Future<void> _run({required bool underAge}) async {
    try {
      final outcome = await _consentManager.requestConsent(underAge: underAge);
      _personalizedAdsAllowed = outcome.personalizedAdsAllowed;
      await _client.updateRequestConfiguration(
        RequestConfiguration(
          ageRestrictedTreatment:
              underAge ? AgeRestrictedTreatment.teen : AgeRestrictedTreatment.unspecified,
        ),
      );
      await _client.initialize();
    } catch (_) {
      // Best-effort — see class doc. personalizedAdsAllowed stays false.
    }
  }
}

/// Overridden with a fake in tests — see [AdsClient]'s doc.
final adsClientProvider = Provider<AdsClient>((ref) => PlatformAdsClient());

/// Overridden with a fake in tests — see [ConsentClient]'s doc.
final consentClientProvider = Provider<ConsentClient>((ref) => PlatformConsentClient());

final consentManagerProvider =
    Provider<ConsentManager>((ref) => ConsentManager(ref.watch(consentClientProvider)));

/// Watched once at app root (`LifeyApp`), same as `EntitlementRefresher` —
/// its constructor-time `ref.listen` is what actually drives the "only
/// after the first successful entitlement resolve, and only if `adsEnabled`"
/// timing (`67` §5.1). The return value is otherwise unused by the app root;
/// [personalizedAdsAllowed] is read later by the ad-request builders.
final adsServiceProvider = Provider<AdsService>((ref) {
  final service = AdsService(ref.watch(adsClientProvider), ref.watch(consentManagerProvider));
  ref.listen(entitlementProvider, (previous, next) {
    final entitlement = next.value;
    if (entitlement == null || !entitlement.resolved || !entitlement.adsEnabled) return;
    unawaited(_bootstrap(ref, service));
  }, fireImmediately: true);
  return service;
});

Future<void> _bootstrap(Ref ref, AdsService service) async {
  UserDetails? userDetails;
  try {
    userDetails = await ref.read(userDetailsProvider.future);
  } catch (_) {
    userDetails = null;
  }
  await service.ensureInitialized(underAge: isUnderConsentAge(userDetails?.birthDate));
}

/// `67` §9.6: an unknown birth date (not onboarded yet, or the fetch
/// failed) is treated as under-consent-age — the restrictive direction, the
/// opposite of the entitlement rule's fail-open default, and that asymmetry
/// is deliberate.
bool isUnderConsentAge(DateTime? birthDate) {
  if (birthDate == null) return true;
  final now = DateTime.now();
  var age = now.year - birthDate.year;
  final birthdayPassedThisYear =
      now.month > birthDate.month || (now.month == birthDate.month && now.day >= birthDate.day);
  if (!birthdayPassedThisYear) age--;
  return age < 16;
}
