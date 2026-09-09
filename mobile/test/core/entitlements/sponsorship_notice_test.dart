import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/entitlement.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/entitlements/sponsorship_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `69` §12.1, built in `72` Prompt 10: a client whose trainer stops paying
/// gets exactly one quiet notice, and only when Pro has actually gone away.

Entitlement _entitlement({
  required EntitlementTier tier,
  required EntitlementSource source,
  bool resolved = true,
}) {
  final now = DateTime.now();
  return Entitlement(
    tier: tier,
    source: source,
    adsEnabled: tier == EntitlementTier.free,
    historyDays: tier == EntitlementTier.free ? 30 : null,
    aiCreditsRemaining: tier == EntitlementTier.free ? 3 : null,
    trainer: null,
    expiresAt: null,
    checkedAt: now,
    graceUntil: now.add(const Duration(days: 7)),
    degraded: false,
    resolved: resolved,
  );
}

final _sponsored = _entitlement(
  tier: EntitlementTier.pro,
  source: EntitlementSource.trainerSponsored,
);
final _free = _entitlement(tier: EntitlementTier.free, source: EntitlementSource.none);
final _ownPro = _entitlement(
  tier: EntitlementTier.pro,
  source: EntitlementSource.appStore,
);

class _StreamedEntitlementController extends EntitlementController {
  _StreamedEntitlementController(this._stream);
  final Stream<Entitlement> _stream;

  @override
  Stream<Entitlement> build() => _stream;
}

void main() {
  group('sponsorshipNoticeActionFor', () {
    test('remembers a sponsorship the first time it is seen', () {
      expect(
        sponsorshipNoticeActionFor(wasSponsored: false, entitlement: _sponsored),
        SponsorshipNoticeAction.remember,
      );
    });

    test('does nothing while the sponsorship simply continues', () {
      expect(
        sponsorshipNoticeActionFor(wasSponsored: true, entitlement: _sponsored),
        SponsorshipNoticeAction.none,
      );
    });

    test('notifies when a remembered sponsorship has dropped to the free tier', () {
      expect(
        sponsorshipNoticeActionFor(wasSponsored: true, entitlement: _free),
        SponsorshipNoticeAction.notify,
      );
    });

    test('stays quiet when the user replaced sponsored Pro with their own purchase', () {
      // Nothing was lost, so there is nothing to explain.
      expect(
        sponsorshipNoticeActionFor(wasSponsored: true, entitlement: _ownPro),
        SponsorshipNoticeAction.forget,
      );
    });

    test('never fires for a user who was never sponsored', () {
      expect(
        sponsorshipNoticeActionFor(wasSponsored: false, entitlement: _free),
        SponsorshipNoticeAction.none,
      );
    });

    test('ignores an unresolved snapshot, which fails open as Pro (D-P4)', () {
      // The cold-start snapshot reports `tier: pro, source: none`. Read
      // literally that is "sponsorship ended" for a remembered sponsee, and
      // the notice would fire on every launch before the first refresh.
      expect(
        sponsorshipNoticeActionFor(
          wasSponsored: true,
          entitlement: Entitlement.unresolvedOpen(),
        ),
        SponsorshipNoticeAction.none,
      );
    });

    test('fires on an expired offline grace, which resolves to free (D-M10)', () {
      final decayed = Entitlement.decayedToFree(
        checkedAt: DateTime.now().subtract(const Duration(days: 9)),
        graceUntil: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(
        sponsorshipNoticeActionFor(wasSponsored: true, entitlement: decayed),
        SponsorshipNoticeAction.notify,
      );
    });
  });

  group('SponsorshipNoticeController', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    ProviderContainer containerFor(Stream<Entitlement> stream) {
      final container = ProviderContainer(
        overrides: [
          entitlementProvider.overrideWith(() => _StreamedEntitlementController(stream)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('a sponsored client sees no card', () async {
      final container = containerFor(Stream.value(_sponsored));
      container.listen(entitlementProvider, (_, __) {});

      await container.read(sponsorshipNoticeProvider.future);
      expect(container.read(sponsorshipNoticeProvider).value, isFalse);
    });

    test('the card appears when the sponsorship ends, and survives a restart', () async {
      final controller = StreamController<Entitlement>();
      addTearDown(controller.close);
      final container = containerFor(controller.stream);
      container.listen(entitlementProvider, (_, __) {});
      container.listen(sponsorshipNoticeProvider, (_, __) {});

      await container.read(sponsorshipNoticeProvider.future);

      controller.add(_sponsored);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(sponsorshipNoticeProvider).value, isFalse);

      controller.add(_free);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(sponsorshipNoticeProvider).value, isTrue);

      // A cold start reads the same pending flag back out of prefs, so the
      // one notice isn't lost to a process restart between "grace expired"
      // and "user next opened the dashboard".
      final restarted = containerFor(Stream.value(_free));
      restarted.listen(entitlementProvider, (_, __) {});
      expect(await restarted.read(sponsorshipNoticeProvider.future), isTrue);
    });

    test('dismissing is permanent — the notice is shown once (69 §12.1)', () async {
      SharedPreferences.setMockInitialValues({
        'entitlements.sponsorshipEndedNoticePending': true,
      });
      final container = containerFor(Stream.value(_free));
      container.listen(entitlementProvider, (_, __) {});

      expect(await container.read(sponsorshipNoticeProvider.future), isTrue);

      await container.read(sponsorshipNoticeProvider.notifier).dismiss();
      expect(container.read(sponsorshipNoticeProvider).value, isFalse);

      final restarted = containerFor(Stream.value(_free));
      restarted.listen(entitlementProvider, (_, __) {});
      expect(await restarted.read(sponsorshipNoticeProvider.future), isFalse);
    });

    test('buying Pro after a sponsorship ends never triggers a stale notice', () async {
      final controller = StreamController<Entitlement>();
      addTearDown(controller.close);
      final container = containerFor(controller.stream);
      container.listen(entitlementProvider, (_, __) {});
      container.listen(sponsorshipNoticeProvider, (_, __) {});
      await container.read(sponsorshipNoticeProvider.future);

      controller.add(_sponsored);
      await Future<void>.delayed(Duration.zero);
      controller.add(_ownPro);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(sponsorshipNoticeProvider).value, isFalse);
    });
  });
}
