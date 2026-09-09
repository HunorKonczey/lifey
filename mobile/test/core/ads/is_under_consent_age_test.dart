import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/ads/ads_service.dart';

void main() {
  test('null birth date (unknown) is treated as under-consent-age (67 §9.6)', () {
    expect(isUnderConsentAge(null), isTrue);
  });

  test('someone who just turned 16 today is not under-consent-age', () {
    final now = DateTime.now();
    final birthDate = DateTime(now.year - 16, now.month, now.day);
    expect(isUnderConsentAge(birthDate), isFalse);
  });

  test("someone who turns 16 tomorrow is still under-consent-age", () {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final birthDate = DateTime(tomorrow.year - 16, tomorrow.month, tomorrow.day);
    expect(isUnderConsentAge(birthDate), isTrue);
  });

  test('a clearly adult birth date is not under-consent-age', () {
    expect(isUnderConsentAge(DateTime(1990, 1, 1)), isFalse);
  });

  test('a 15-year-old is under-consent-age', () {
    final now = DateTime.now();
    final birthDate = DateTime(now.year - 15, now.month, now.day);
    expect(isUnderConsentAge(birthDate), isTrue);
  });
}
