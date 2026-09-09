import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lifey/core/ads/ads_client.dart';
import 'package:lifey/core/ads/ads_service.dart';
import 'package:lifey/core/ads/consent_client.dart';
import 'package:lifey/core/entitlements/entitlement.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/features/onboarding/data/user_details_repository.dart';

/// Covers Prompt 8's own verify line: a Pro account never triggers the
/// consent flow; consent-refused produces non-personalized configuration;
/// the app starts normally with no network.

class _FakeAdsClient implements AdsClient {
  int initializeCallCount = 0;

  @override
  Future<InitializationStatus> initialize() async {
    initializeCallCount++;
    return InitializationStatus(const {});
  }

  @override
  Future<void> updateRequestConfiguration(RequestConfiguration configuration) async {}
}

class _FakeConsentClient implements ConsentClient {
  ConsentStatus status = ConsentStatus.obtained;
  bool throwOnRequestUpdate = false;
  int requestUpdateCallCount = 0;

  @override
  Future<void> requestConsentInfoUpdate(ConsentRequestParameters params) async {
    requestUpdateCallCount++;
    if (throwOnRequestUpdate) throw Exception('offline');
  }

  @override
  Future<bool> isConsentFormAvailable() async => false;

  @override
  Future<ConsentStatus> getConsentStatus() async => status;

  @override
  Future<FormError?> loadAndShowConsentFormIfRequired() async => null;
}

class _FakeEntitlementController extends EntitlementController {
  _FakeEntitlementController(this._entitlement);
  final Entitlement _entitlement;

  @override
  Stream<Entitlement> build() => Stream.value(_entitlement);
}

Entitlement _entitlement({required bool adsEnabled, bool resolved = true}) {
  final now = DateTime.now();
  return Entitlement(
    tier: adsEnabled ? EntitlementTier.free : EntitlementTier.pro,
    source: adsEnabled ? EntitlementSource.none : EntitlementSource.appStore,
    adsEnabled: adsEnabled,
    historyDays: adsEnabled ? 30 : null,
    aiCreditsRemaining: adsEnabled ? 3 : null,
    trainer: null,
    expiresAt: null,
    checkedAt: now,
    graceUntil: now.add(const Duration(days: 7)),
    degraded: false,
    resolved: resolved,
  );
}

/// [ProviderContainer.read] alone doesn't establish a persistent listener,
/// so a non-autoDispose provider built only that way can still be torn down
/// before its own internal `ref.listen` (on [entitlementProvider]) ever
/// observes a later emission — exactly the gap `app.dart`'s `ref.watch`
/// (a real, continuous watch from the permanently-mounted root widget)
/// doesn't have. [ProviderContainer.listen] is what actually keeps it
/// alive here, matching this codebase's established test convention for
/// stream-backed providers (see `entitlement_providers_test.dart`).
void _keepAlive(ProviderContainer container) {
  container.listen(adsServiceProvider, (_, __) {});
}

void main() {
  test('a Pro account (adsEnabled: false) never triggers the consent flow', () async {
    final adsClient = _FakeAdsClient();
    final consentClient = _FakeConsentClient();
    final container = ProviderContainer(overrides: [
      entitlementProvider
          .overrideWith(() => _FakeEntitlementController(_entitlement(adsEnabled: false))),
      adsClientProvider.overrideWithValue(adsClient),
      consentClientProvider.overrideWithValue(consentClient),
      userDetailsProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);

    _keepAlive(container);
    // The entitlement-gated bootstrap is fire-and-forget (unawaited) — wait
    // for it to settle, same pattern as trainer_invite_controller_test.dart.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(consentClient.requestUpdateCallCount, 0);
    expect(adsClient.initializeCallCount, 0);
  });

  test('an unresolved entitlement never triggers the consent flow either (D-P4)', () async {
    final adsClient = _FakeAdsClient();
    final consentClient = _FakeConsentClient();
    final container = ProviderContainer(overrides: [
      entitlementProvider.overrideWith(
        () => _FakeEntitlementController(_entitlement(adsEnabled: false, resolved: false)),
      ),
      adsClientProvider.overrideWithValue(adsClient),
      consentClientProvider.overrideWithValue(consentClient),
      userDetailsProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);

    _keepAlive(container);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(consentClient.requestUpdateCallCount, 0);
  });

  test('a free account (adsEnabled: true) triggers the consent flow and initializes',
      () async {
    final adsClient = _FakeAdsClient();
    final consentClient = _FakeConsentClient();
    final container = ProviderContainer(overrides: [
      entitlementProvider
          .overrideWith(() => _FakeEntitlementController(_entitlement(adsEnabled: true))),
      adsClientProvider.overrideWithValue(adsClient),
      consentClientProvider.overrideWithValue(consentClient),
      userDetailsProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);

    _keepAlive(container);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(consentClient.requestUpdateCallCount, 1);
    expect(adsClient.initializeCallCount, 1);
  });

  test('consent refused produces a non-personalized configuration', () async {
    final adsClient = _FakeAdsClient();
    final consentClient = _FakeConsentClient()..status = ConsentStatus.required;
    final container = ProviderContainer(overrides: [
      entitlementProvider
          .overrideWith(() => _FakeEntitlementController(_entitlement(adsEnabled: true))),
      adsClientProvider.overrideWithValue(adsClient),
      consentClientProvider.overrideWithValue(consentClient),
      userDetailsProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);

    _keepAlive(container);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(container.read(adsServiceProvider).personalizedAdsAllowed, isFalse);
  });

  test('the app starts normally with no network — a throwing consent client never propagates',
      () async {
    final adsClient = _FakeAdsClient();
    final consentClient = _FakeConsentClient()..throwOnRequestUpdate = true;
    final container = ProviderContainer(overrides: [
      entitlementProvider
          .overrideWith(() => _FakeEntitlementController(_entitlement(adsEnabled: true))),
      adsClientProvider.overrideWithValue(adsClient),
      consentClientProvider.overrideWithValue(consentClient),
      userDetailsProvider.overrideWith((ref) async => throw Exception('offline')),
    ]);
    addTearDown(container.dispose);

    // Building and settling the provider graph must not throw.
    expect(() => _keepAlive(container), returnsNormally);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(container.read(adsServiceProvider).personalizedAdsAllowed, isFalse);
  });
}
