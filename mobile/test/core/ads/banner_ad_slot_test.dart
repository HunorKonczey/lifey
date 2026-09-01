import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lifey/core/ads/banner_ad_loader.dart';
import 'package:lifey/core/ads/banner_ad_slot.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/shell_fab.dart';

/// Covers Prompt 9's verify line: nothing renders for Pro, nothing renders
/// before resolution, no layout shift on a failed load. [BannerAdLoader] is
/// injected so these never touch a real ad SDK platform channel — see its
/// own doc comment. The successful-load render path (a real [AdWidget])
/// isn't covered here: that needs a real platform view, impractical in a
/// widget test, and isn't part of the verify line.

/// Never asked to actually load an ad in these tests — [getAdaptiveSize]
/// returning `null` is itself the "failed load, no layout shift" case.
class _UnavailableSizeLoader implements BannerAdLoader {
  int getAdaptiveSizeCallCount = 0;

  @override
  Future<AnchoredAdaptiveBannerAdSize?> getAdaptiveSize(int width) async {
    getAdaptiveSizeCallCount++;
    return null;
  }

  @override
  BannerAd load({
    required String adUnitId,
    required AdSize size,
    required AdRequest request,
    required BannerAdListener listener,
  }) {
    throw StateError('load() must never be reached when getAdaptiveSize returns null');
  }
}

Future<ProviderContainer> _pumpSlot(
  WidgetTester tester, {
  required bool adsEnabled,
  int tabIndex = 0,
  int activeTab = 0,
  BannerAdLoader? loader,
}) async {
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adsEnabledProvider.overrideWithValue(adsEnabled),
        if (loader != null) bannerAdLoaderProvider.overrideWithValue(loader),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return Scaffold(body: BannerAdSlot(tabIndex: tabIndex));
          },
        ),
      ),
    ),
  );
  if (activeTab != 0) {
    container.read(activeShellTabProvider.notifier).set(activeTab);
  }
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('a Pro account (adsEnabled: false) renders nothing', (tester) async {
    await _pumpSlot(tester, adsEnabled: false);

    expect(find.byType(BannerAdSlot), findsOneWidget);
    expect(tester.getSize(find.byType(BannerAdSlot)), Size.zero);
  });

  testWidgets(
      'an unresolved entitlement (adsEnabled defaults false until resolved, D-P4) renders nothing',
      (tester) async {
    // adsEnabledProvider itself already defaults to false pre-resolution
    // (entitlement_providers.dart) — this is the same input the widget sees.
    await _pumpSlot(tester, adsEnabled: false);

    expect(tester.getSize(find.byType(BannerAdSlot)), Size.zero);
  });

  testWidgets('a free account on an inactive tab renders nothing', (tester) async {
    await _pumpSlot(tester, adsEnabled: true, tabIndex: 1, activeTab: 0);

    expect(tester.getSize(find.byType(BannerAdSlot)), Size.zero);
  });

  testWidgets('a failed load (no ad size available) causes no layout shift', (tester) async {
    final loader = _UnavailableSizeLoader();

    await _pumpSlot(tester, adsEnabled: true, loader: loader);

    expect(loader.getAdaptiveSizeCallCount, 1);
    expect(tester.getSize(find.byType(BannerAdSlot)), Size.zero);
  });
}
