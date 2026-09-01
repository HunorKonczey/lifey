import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lifey/core/ads/ads_client.dart';
import 'package:lifey/core/ads/ads_service.dart';
import 'package:lifey/core/ads/consent_client.dart';
import 'package:lifey/core/ads/consent_manager.dart';

class _FakeAdsClient implements AdsClient {
  int initializeCallCount = 0;
  RequestConfiguration? lastConfiguration;
  bool throwOnInitialize = false;

  @override
  Future<InitializationStatus> initialize() async {
    initializeCallCount++;
    if (throwOnInitialize) throw Exception('offline');
    return InitializationStatus(const {});
  }

  @override
  Future<void> updateRequestConfiguration(RequestConfiguration configuration) async {
    lastConfiguration = configuration;
  }
}

class _FakeConsentClient implements ConsentClient {
  ConsentStatus status = ConsentStatus.obtained;
  int requestUpdateCallCount = 0;

  @override
  Future<void> requestConsentInfoUpdate(ConsentRequestParameters params) async {
    requestUpdateCallCount++;
  }

  @override
  Future<bool> isConsentFormAvailable() async => false;

  @override
  Future<ConsentStatus> getConsentStatus() async => status;

  @override
  Future<FormError?> loadAndShowConsentFormIfRequired() async => null;
}

void main() {
  late _FakeAdsClient adsClient;
  late _FakeConsentClient consentClient;
  late AdsService service;

  setUp(() {
    adsClient = _FakeAdsClient();
    consentClient = _FakeConsentClient();
    service = AdsService(adsClient, ConsentManager(consentClient));
  });

  test('runs consent then applies configuration then initializes, in order', () async {
    await service.ensureInitialized(underAge: false);

    expect(consentClient.requestUpdateCallCount, 1);
    expect(adsClient.lastConfiguration, isNotNull);
    expect(adsClient.initializeCallCount, 1);
    expect(service.personalizedAdsAllowed, isTrue);
  });

  test('applies teen age-restricted treatment when underAge, unspecified otherwise', () async {
    await service.ensureInitialized(underAge: true);
    expect(adsClient.lastConfiguration!.ageRestrictedTreatment, AgeRestrictedTreatment.teen);

    final other = AdsService(_FakeAdsClient(), ConsentManager(_FakeConsentClient()));
    await other.ensureInitialized(underAge: false);
  });

  test('a refused consent (status required) leaves personalizedAdsAllowed false', () async {
    consentClient.status = ConsentStatus.required;

    await service.ensureInitialized(underAge: false);

    expect(service.personalizedAdsAllowed, isFalse);
  });

  test('is idempotent: a second call does not re-run consent or init', () async {
    await service.ensureInitialized(underAge: false);
    await service.ensureInitialized(underAge: false);

    expect(consentClient.requestUpdateCallCount, 1);
    expect(adsClient.initializeCallCount, 1);
  });

  test('concurrent calls before the first resolves still only run once', () async {
    final first = service.ensureInitialized(underAge: false);
    final second = service.ensureInitialized(underAge: false);
    await Future.wait([first, second]);

    expect(consentClient.requestUpdateCallCount, 1);
  });

  test('an SDK init failure (e.g. no network) never throws — the app starts normally',
      () async {
    adsClient.throwOnInitialize = true;

    await expectLater(service.ensureInitialized(underAge: false), completes);
  });

  test('personalizedAdsAllowed still reflects the consent outcome even if init itself fails',
      () async {
    adsClient.throwOnInitialize = true;
    consentClient.status = ConsentStatus.obtained;

    await service.ensureInitialized(underAge: false);

    expect(service.personalizedAdsAllowed, isTrue);
  });

  test('personalizedAdsAllowed defaults to false before ensureInitialized resolves', () {
    expect(service.personalizedAdsAllowed, isFalse);
  });
}
