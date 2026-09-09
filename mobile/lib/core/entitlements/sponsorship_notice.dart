import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'entitlement.dart';
import 'entitlement_providers.dart';

const _wasSponsoredKey = 'entitlements.wasSponsored';
const _noticePendingKey = 'entitlements.sponsorshipEndedNoticePending';

/// What the observed entitlement means for the sponsorship notice
/// (`69` §12.1, decided there; built in `72` Prompt 10).
enum SponsorshipNoticeAction {
  /// Nothing changed that this feature cares about.
  none,

  /// The user is sponsored right now — remember it, so the *end* of it can be
  /// recognised later.
  remember,

  /// They were sponsored and are still Pro, just from another source (they
  /// bought it themselves). Nothing was lost, so nothing is announced —
  /// forget the sponsorship and stay quiet.
  forget,

  /// Sponsored Pro is gone and the user is on the free tier: show the notice,
  /// once.
  notify,
}

/// The whole rule, as a pure function — the part worth testing.
///
/// Deliberately keyed off "is the resolved entitlement still Pro", not off
/// "did the trainer relationship end": a client whose trainer's subscription
/// lapsed keeps Pro for the 7-day grace (D-M10), and telling them their Pro is
/// gone while it demonstrably still works is the failure mode `72` §6 warns
/// about. `Entitlement.decayedToFree` — the offline expiry of that same grace
/// — resolves to `tier: free, source: none`, so it lands here as a `notify`
/// too, which is correct: from the user's side that is the same event.
///
/// An **unresolved** snapshot never triggers anything (D-P4 fails open and
/// reports `tier: pro`, which would otherwise read as "still sponsored" on a
/// cold start before the first refresh).
SponsorshipNoticeAction sponsorshipNoticeActionFor({
  required bool wasSponsored,
  required Entitlement entitlement,
}) {
  if (!entitlement.resolved) return SponsorshipNoticeAction.none;

  final sponsoredNow = entitlement.source == EntitlementSource.trainerSponsored &&
      entitlement.tier == EntitlementTier.pro;
  if (sponsoredNow) {
    return wasSponsored ? SponsorshipNoticeAction.none : SponsorshipNoticeAction.remember;
  }
  if (!wasSponsored) return SponsorshipNoticeAction.none;

  return entitlement.tier == EntitlementTier.pro
      ? SponsorshipNoticeAction.forget
      : SponsorshipNoticeAction.notify;
}

/// Device-local memory for the two flags the rule above needs. Same
/// `shared_preferences` shape and reasoning as `RecapPreferences` and
/// `InterstitialPreferences`: "has *this device* already told this user their
/// sponsorship ended" is not something to reconcile across devices, and it is
/// not secret.
class SponsorshipPreferences {
  Future<bool> wasSponsored() async =>
      (await SharedPreferences.getInstance()).getBool(_wasSponsoredKey) ?? false;

  Future<void> setWasSponsored(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_wasSponsoredKey, value);

  Future<bool> noticePending() async =>
      (await SharedPreferences.getInstance()).getBool(_noticePendingKey) ?? false;

  Future<void> setNoticePending(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_noticePendingKey, value);
}

final sponsorshipPreferencesProvider =
    Provider<SponsorshipPreferences>((ref) => SponsorshipPreferences());

/// Whether the dashboard should be showing the "your coach's Pro has ended"
/// card right now (`69` §12.1: one notice, once, never a modal, no push, and
/// no paywall redirect — the reassurance that the data is still there is the
/// important half).
class SponsorshipNoticeController extends AsyncNotifier<bool> {
  SponsorshipPreferences get _prefs => ref.read(sponsorshipPreferencesProvider);

  @override
  Future<bool> build() async {
    // Later transitions arrive here. The first one is handled below rather
    // than with `fireImmediately`, so the flag is written before this
    // future's own return value reads it back.
    ref.listen<AsyncValue<Entitlement>>(entitlementProvider, (previous, next) {
      final entitlement = next.value;
      if (entitlement != null) unawaited(_apply(entitlement, updateState: true));
    });

    final current = ref.read(entitlementProvider).value;
    if (current != null) await _apply(current, updateState: false);
    return _prefs.noticePending();
  }

  Future<void> _apply(Entitlement entitlement, {required bool updateState}) async {
    final action = sponsorshipNoticeActionFor(
      wasSponsored: await _prefs.wasSponsored(),
      entitlement: entitlement,
    );
    switch (action) {
      case SponsorshipNoticeAction.none:
        return;
      case SponsorshipNoticeAction.remember:
        await _prefs.setWasSponsored(true);
      case SponsorshipNoticeAction.forget:
        await _prefs.setWasSponsored(false);
      case SponsorshipNoticeAction.notify:
        await _prefs.setWasSponsored(false);
        await _prefs.setNoticePending(true);
        if (updateState) state = const AsyncData(true);
    }
  }

  /// Dismissal is permanent — "once" is the whole point of §12.1.
  Future<void> dismiss() async {
    state = const AsyncData(false);
    await _prefs.setNoticePending(false);
  }
}

final sponsorshipNoticeProvider =
    AsyncNotifierProvider<SponsorshipNoticeController, bool>(SponsorshipNoticeController.new);
