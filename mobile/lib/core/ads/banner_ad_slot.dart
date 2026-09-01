import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/shell_fab.dart';
import '../entitlements/entitlement_providers.dart';
import '../entitlements/paywall_navigation.dart';
import '../entitlements/paywall_trigger.dart';
import '../theme/app_tokens.dart';
import 'ads_service.dart';
import 'banner_ad_loader.dart';

/// Google's public **test** banner ad unit ids — distinct from the test app
/// ids already in `Info.plist`/`AndroidManifest.xml` (`67` Prompt 8). Swap
/// for the real per-platform ids from the AdMob console before release.
String bannerAdUnitId() => Platform.isIOS
    ? 'ca-app-pub-3940256099942544/2934735716'
    : 'ca-app-pub-3940256099942544/6300978111';

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
          ref.read(bannerAdSlotHeightProvider(widget.tabIndex).notifier).set(size.height.toDouble());
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
      label: l10n.bannerAdSemanticsLabel,
      child: Container(
        height: ad.size.height.toDouble(),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AdWidget(ad: ad),
            Positioned(
              top: 0,
              right: 0,
              child: SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  icon: const Icon(Icons.block, size: 24),
                  tooltip: l10n.bannerRemoveAdsTooltip,
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.surfaceContainer.withValues(alpha: 0.85),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                  ),
                  onPressed: () => openPaywall(context, PaywallTrigger.adRemoval),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
