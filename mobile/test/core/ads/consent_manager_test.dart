import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lifey/core/ads/consent_client.dart';
import 'package:lifey/core/ads/consent_manager.dart';

class _FakeConsentClient implements ConsentClient {
  bool formAvailable = false;
  ConsentStatus status = ConsentStatus.notRequired;
  bool throwOnRequestUpdate = false;

  int requestUpdateCallCount = 0;
  int loadAndShowCallCount = 0;
  ConsentRequestParameters? lastParams;

  @override
  Future<void> requestConsentInfoUpdate(ConsentRequestParameters params) async {
    requestUpdateCallCount++;
    lastParams = params;
    if (throwOnRequestUpdate) throw Exception('offline');
  }

  @override
  Future<bool> isConsentFormAvailable() async => formAvailable;

  @override
  Future<ConsentStatus> getConsentStatus() async => status;

  @override
  Future<FormError?> loadAndShowConsentFormIfRequired() async {
    loadAndShowCallCount++;
    return null;
  }
}

void main() {
  late _FakeConsentClient client;
  late ConsentManager manager;

  setUp(() {
    client = _FakeConsentClient();
    manager = ConsentManager(client);
  });

  test('obtained consent, not underage: personalized ads allowed', () async {
    client.status = ConsentStatus.obtained;

    final outcome = await manager.requestConsent(underAge: false);

    expect(outcome.personalizedAdsAllowed, isTrue);
  });

  test('consent not required (e.g. outside the EEA), not underage: personalized ads allowed',
      () async {
    client.status = ConsentStatus.notRequired;

    final outcome = await manager.requestConsent(underAge: false);

    expect(outcome.personalizedAdsAllowed, isTrue);
  });

  test('consent refused (status stays required): non-personalized (67 §5.1)', () async {
    client.status = ConsentStatus.required;

    final outcome = await manager.requestConsent(underAge: false);

    expect(outcome.personalizedAdsAllowed, isFalse);
  });

  test('underage overrides an otherwise-obtained consent: non-personalized', () async {
    client.status = ConsentStatus.obtained;

    final outcome = await manager.requestConsent(underAge: true);

    expect(outcome.personalizedAdsAllowed, isFalse);
  });

  test('passes tagForUnderAgeOfConsent through to the request', () async {
    await manager.requestConsent(underAge: true);
    expect(client.lastParams?.tagForUnderAgeOfConsent, isTrue);

    await manager.requestConsent(underAge: false);
    expect(client.lastParams?.tagForUnderAgeOfConsent, isFalse);
  });

  test('loads and shows the form only when one is available', () async {
    client.formAvailable = true;
    await manager.requestConsent(underAge: false);
    expect(client.loadAndShowCallCount, 1);

    client.formAvailable = false;
    await manager.requestConsent(underAge: false);
    expect(client.loadAndShowCallCount, 1); // unchanged
  });

  test('a failure (e.g. offline) never throws, and resolves to non-personalized (D-M7)',
      () async {
    client.throwOnRequestUpdate = true;

    final outcome = await manager.requestConsent(underAge: false);

    expect(outcome.personalizedAdsAllowed, isFalse);
  });
}
