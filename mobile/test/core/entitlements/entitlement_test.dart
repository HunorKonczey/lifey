import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement.dart';

void main() {
  group('EntitlementSource wire mapping', () {
    for (final pair in {
      EntitlementSource.none: 'NONE',
      EntitlementSource.stripe: 'STRIPE',
      EntitlementSource.appStore: 'APP_STORE',
      EntitlementSource.playStore: 'PLAY_STORE',
      EntitlementSource.trainerSponsored: 'TRAINER_SPONSORED',
      EntitlementSource.trainerTrial: 'TRAINER_TRIAL',
      EntitlementSource.comp: 'COMP',
    }.entries) {
      test('${pair.key} <-> ${pair.value} round-trips', () {
        expect(pair.key.wireName, pair.value);
        expect(EntitlementSource.fromWire(pair.value), pair.key);
      });
    }

    test('an unrecognized wire value falls back to none rather than throwing', () {
      expect(EntitlementSource.fromWire('SOMETHING_NEW'), EntitlementSource.none);
    });
  });

  group('Entitlement.fromJson', () {
    test('parses a free response', () {
      final json = {
        'tier': 'FREE',
        'source': 'NONE',
        'adsEnabled': true,
        'historyDays': 30,
        'aiCreditsRemaining': 3,
        'trainer': null,
        'expiresAt': null,
        'checkedAt': '2026-08-25T09:14:00Z',
        'graceUntil': '2026-09-01T09:14:00Z',
        'degraded': false,
      };

      final entitlement = Entitlement.fromJson(json);

      expect(entitlement.tier, EntitlementTier.free);
      expect(entitlement.source, EntitlementSource.none);
      expect(entitlement.adsEnabled, isTrue);
      expect(entitlement.historyDays, 30);
      expect(entitlement.aiCreditsRemaining, 3);
      expect(entitlement.trainer, isNull);
      expect(entitlement.expiresAt, isNull);
      expect(entitlement.checkedAt, DateTime.parse('2026-08-25T09:14:00Z'));
      expect(entitlement.graceUntil, DateTime.parse('2026-09-01T09:14:00Z'));
      expect(entitlement.degraded, isFalse);
      expect(entitlement.resolved, isTrue);
    });

    test('null historyDays/aiCreditsRemaining mean unlimited, not zero', () {
      final json = {
        'tier': 'PRO',
        'source': 'TRAINER_SPONSORED',
        'adsEnabled': false,
        'historyDays': null,
        'aiCreditsRemaining': null,
        'trainer': {
          'plan': 'PRO',
          'status': 'ACTIVE',
          'maxClients': 25,
          'activeClients': 11,
          'trialEndsAt': null,
        },
        'expiresAt': '2026-09-24T00:00:00Z',
        'checkedAt': '2026-08-25T09:14:00Z',
        'graceUntil': '2026-09-01T09:14:00Z',
        'degraded': true,
      };

      final entitlement = Entitlement.fromJson(json);

      expect(entitlement.historyDays, isNull);
      expect(entitlement.aiCreditsRemaining, isNull);
      expect(entitlement.trainer!.maxClients, 25);
      expect(entitlement.trainer!.activeClients, 11);
      expect(entitlement.degraded, isTrue);
    });
  });

  group('synthetic states', () {
    test('unresolvedOpen behaves like Pro but is not resolved', () {
      final entitlement = Entitlement.unresolvedOpen();

      expect(entitlement.resolved, isFalse);
      expect(entitlement.adsEnabled, isFalse);
      expect(entitlement.historyDays, isNull);
      expect(entitlement.aiCreditsRemaining, isNull);
    });

    test('decayedToFree is resolved and gates like a real free response', () {
      final checkedAt = DateTime.utc(2026, 1, 1);
      final graceUntil = checkedAt.add(const Duration(days: 7));

      final entitlement = Entitlement.decayedToFree(checkedAt: checkedAt, graceUntil: graceUntil);

      expect(entitlement.resolved, isTrue);
      expect(entitlement.tier, EntitlementTier.free);
      expect(entitlement.adsEnabled, isTrue);
      expect(entitlement.historyDays, isNotNull);
      expect(entitlement.aiCreditsRemaining, 0);
      expect(entitlement.checkedAt, checkedAt);
      expect(entitlement.graceUntil, graceUntil);
    });
  });
}
