import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/shell_fab.dart';
import '../entitlements/entitlement_providers.dart';
import '../entitlements/paywall_navigation.dart';
import '../entitlements/paywall_trigger.dart';
import '../theme/app_tokens.dart';
import 'ad_ids.dart';
import 'ads_service.dart';
import 'banner_ad_loader.dart';
import 'nav_reserved_space.dart';

/// Overridden with a fake in tests — see [BannerAdLoader]'s doc.
final bannerAdLoaderProvider = Provider<BannerAdLoader>((ref) => PlatformBannerAdLoader());

class _BannerAdSlotHeightNotifier extends Notifier<double> {
  _BannerAdSlotHeightNotifier(this.tabIndex);

  final int tabIndex;

  @override
  double build() => 0;

  void set(double height) => state = height;
}

/// The reserved height of the [BannerAdSlot] on shell tab [tabIndex] —
/// zero until that slot has an ad actually loaded. Keyed by tab rather than
/// a single shared value so a background tab's slot can never leave a stale
/// reservation behind for whichever tab becomes active next; `main_shell.dart`
/// only ever reads the entry for `activeShellTabProvider`'s current value.
final bannerAdSlotHeightProvider =
    NotifierProvider.family<_BannerAdSlotHeightNotifier, double, int>(
  _BannerAdSlotHeightNotifier.new,
);

/// The only ad widget a feature ever touches (`67` §5.2) — placed on each of
/// the four tab roots and nowhere else (`69` §12.5). [tabIndex] must match
/// this screen's shell branch index (see `shell_fab.dart`); the slot only
/// loads/shows an ad while its own tab is the active one, so a tab kept
/// alive in the background by `StatefulShellRoute.indexedStack` never loads
/// an ad nobody can see.
///
/// Renders zero height — no reserved gap, no hairline, no label — unless
/// [adsEnabledProvider] is true (which is already `false` for both Pro *and*
/// an unresolved snapshot, D-P4) **and** this tab is active **and** a real
/// ad has actually loaded. A failed load leaves it at zero height too: no
/// layout shift either way (`69` P17).
class BannerAdSlot extends ConsumerStatefulWidget {
  const BannerAdSlot({super.key, required this.tabIndex});

  final int tabIndex;

  @override
  ConsumerState<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends ConsumerState<BannerAdSlot> {
  BannerAd? _ad;
  bool _requested = false;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  Future<void> _requestAd(double width) async {
    if (_requested) return;
    _requested = true;
    final loader = ref.read(bannerAdLoaderProvider);
    final size = await loader.getAdaptiveSize(width.truncate());
    if (!mounted || size == null) return;
    final personalizedAdsAllowed = ref.read(adsServiceProvider).personalizedAdsAllowed;
    loader.load(
      adUnitId: bannerAdUnitId(),
      size: size,
      request: AdRequest(nonPersonalizedAds: !personalizedAdsAllowed),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _ad = ad as BannerAd);
          // The chrome row counts: everything that pads content or places a
          // FAB reads this number (`nav_reserved_space.dart`).
          ref
              .read(bannerAdSlotHeightProvider(widget.tabIndex).notifier)
              .set(bannerSlotHeight(size.height.toDouble()));
        },
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adsEnabled = ref.watch(adsEnabledProvider);
    final isActiveTab = ref.watch(activeShellTabProvider) == widget.tabIndex;

    if (!adsEnabled || !isActiveTab) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width;
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestAd(width));

    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label: l10n.bannerAdSemanticsLabel,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        // A Column, not a Stack: nothing of ours may be painted on top of a
        // served creative (`72` D-F3). The earlier version overlaid the
        // remove-ads button on the ad's top-right corner, which is both an
        // obscured ad and an accidental-click generator under AdMob's
        // policies — and it dropped the "Reklám" label entirely, which
        // `69` §4.4 and §9 both require.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BannerAdChrome(),
            SizedBox(
              height: ad.size.height.toDouble(),
              width: ad.size.width.toDouble(),
              child: AdWidget(ad: ad),
            ),
          ],
        ),
      ),
    );
  }
}

/// The slot's own furniture: the "Reklám" label and the remove-ads button,
/// in a row **above** the creative (`69` §4.4, frame P15 — which draws exactly
/// this: a 12 px muted label left, a 24 px `block` glyph in a 44 × 28 target
/// right).
///
/// Public and separate from [BannerAdSlot] so it can be widget-tested on its
/// own: the slot's loaded state contains a real platform-view [AdWidget] and
/// cannot be pumped in a widget test (see `banner_ad_slot_test.dart`).
class BannerAdChrome extends StatelessWidget {
  const BannerAdChrome({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: bannerAdChromeHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 6, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // The visible label is what makes the ad honest; the slot's
            // Semantics container already says "Hirdetés" to a screen
            // reader, so reading both would be a stutter.
            ExcludeSemantics(
              child: Text(
                l10n.bannerAdLabel,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.block, size: 20),
              tooltip: l10n.bannerRemoveAdsTooltip,
              color: scheme.onSurfaceVariant,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 28),
              // `shrinkWrap`, or Material's default 48 dp minimum tap target
              // would silently grow the touch area past the visible control
              // and back down over the creative — the same accidental-click
              // problem this row exists to remove, just invisible.
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              onPressed: () => openPaywall(context, PaywallTrigger.adRemoval),
            ),
          ],
        ),
      ),
    );
  }
}
