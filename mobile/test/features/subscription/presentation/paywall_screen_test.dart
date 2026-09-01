import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lifey/core/entitlements/entitlement.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/core/entitlements/paywall_trigger.dart';
import 'package:lifey/features/subscription/data/purchase_repository.dart';
import 'package:lifey/features/subscription/data/store_purchase_client.dart';
import 'package:lifey/features/subscription/domain/subscription_product.dart';
import 'package:lifey/features/subscription/presentation/paywall_screen.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// Covers Prompt 6's own verify line: a widget test per trigger, the
/// sponsored state rendering no purchase button, and a golden-free layout
/// test at 320 pt width.

class _FakeStorePurchaseClient implements StorePurchaseClient {
  _FakeStorePurchaseClient({this.products = const []});

  final List<ProductDetails> products;
  final _purchaseController = StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    return ProductDetailsResponse(productDetails: products, notFoundIDs: const []);
  }

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchaseController.stream;

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async => true;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases() async {}
}

class _FakeEntitlementController extends EntitlementController {
  _FakeEntitlementController(this._entitlement);
  final Entitlement _entitlement;

  @override
  Stream<Entitlement> build() => Stream.value(_entitlement);
}

ProductDetails _productDetails(String id, {String price = '\$4.99', double rawPrice = 4.99}) {
  return ProductDetails(
    id: id,
    title: 'Lifey Pro',
    description: 'Lifey Pro subscription',
    price: price,
    rawPrice: rawPrice,
    currencyCode: 'USD',
  );
}

final _defaultProducts = [
  _productDetails(monthlySubscriptionProductId, price: '\$4.99', rawPrice: 4.99),
  _productDetails(yearlySubscriptionProductId, price: '\$39.99', rawPrice: 39.99),
];

Entitlement _entitlement({required EntitlementTier tier, required EntitlementSource source}) {
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
    resolved: true,
  );
}

final _freeEntitlement = _entitlement(tier: EntitlementTier.free, source: EntitlementSource.none);

Future<void> _pumpPaywall(
  WidgetTester tester, {
  required PaywallTrigger trigger,
  Entitlement? entitlement,
  List<ProductDetails>? products,
}) async {
  final client = _FakeStorePurchaseClient(products: products ?? _defaultProducts);
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));

  final router = GoRouter(
    initialLocation: '/host',
    routes: [
      GoRoute(
        path: '/host',
        builder: (context, state) => const Scaffold(body: SizedBox()),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => PaywallScreen(trigger: trigger),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        entitlementProvider.overrideWith(() => _FakeEntitlementController(entitlement ?? _freeEntitlement)),
        purchaseRepositoryProvider.overrideWithValue(PurchaseRepository(client, dio)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/paywall');
  await tester.pumpAndSettle();
}

void main() {
  group('one widget test per trigger', () {
    testWidgets('historyRange shows its headline and highlights full history', (tester) async {
      await _pumpPaywall(tester, trigger: PaywallTrigger.historyRange);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.paywallHeadlineHistoryRange), findsOneWidget);
      expect(find.text(l10n.paywallSubHistoryRange), findsOneWidget);
    });

    testWidgets('aiCredits shows its headline', (tester) async {
      await _pumpPaywall(tester, trigger: PaywallTrigger.aiCredits);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.paywallHeadlineAiCredits), findsOneWidget);
      expect(find.text(l10n.paywallSubAiCredits), findsOneWidget);
    });

    testWidgets('adRemoval shows its headline', (tester) async {
      await _pumpPaywall(tester, trigger: PaywallTrigger.adRemoval);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.paywallHeadlineAdRemoval), findsOneWidget);
      expect(find.text(l10n.paywallSubAdRemoval), findsOneWidget);
    });

    testWidgets('settings shows the neutral "Lifey Pro" headline (69 §3.2)', (tester) async {
      await _pumpPaywall(tester, trigger: PaywallTrigger.settings);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.lifeyProLabel), findsOneWidget);
      expect(find.text(l10n.paywallSubNeutral), findsOneWidget);
    });

    testWidgets('onboarding shows its headline, sharing the neutral sub-line with settings',
        (tester) async {
      await _pumpPaywall(tester, trigger: PaywallTrigger.onboarding);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.paywallHeadlineOnboarding), findsOneWidget);
      expect(find.text(l10n.paywallSubNeutral), findsOneWidget);
    });
  });

  group('sponsored state (D-P9)', () {
    testWidgets('renders no purchase button, no plan selector, no restore', (tester) async {
      await _pumpPaywall(
        tester,
        trigger: PaywallTrigger.settings,
        entitlement:
            _entitlement(tier: EntitlementTier.pro, source: EntitlementSource.trainerSponsored),
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.paywallSponsoredHeadline), findsOneWidget);
      expect(find.text(l10n.paywallSponsoredOkButton), findsOneWidget);
      // No purchase button: neither plan label appears...
      expect(find.text(l10n.paywallPlanMonthlyLabel), findsNothing);
      expect(find.text(l10n.paywallPlanYearlyLabel), findsNothing);
      // ...nor the CTA, nor restore.
      expect(find.textContaining('Subscribe'), findsNothing);
      expect(find.text(l10n.paywallRestoreButton), findsNothing);
    });

    testWidgets('the OK button closes the paywall', (tester) async {
      await _pumpPaywall(
        tester,
        trigger: PaywallTrigger.settings,
        entitlement:
            _entitlement(tier: EntitlementTier.pro, source: EntitlementSource.trainerSponsored),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(l10n.paywallSponsoredOkButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.paywallSponsoredHeadline), findsNothing);
    });
  });

  group('already-Pro state, reached e.g. by deep link (69 §3.3)', () {
    testWidgets('own store purchase shows "Manage", not a purchase flow', (tester) async {
      await _pumpPaywall(
        tester,
        trigger: PaywallTrigger.settings,
        entitlement: _entitlement(tier: EntitlementTier.pro, source: EntitlementSource.appStore),
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.paywallAlreadyProHeadline), findsOneWidget);
      expect(find.text(l10n.paywallManageSubscriptionButton), findsOneWidget);
      expect(find.text(l10n.paywallPlanMonthlyLabel), findsNothing);
    });
  });

  group('unresolved entitlement never flashes an already-Pro/sponsored state (D-P4)', () {
    testWidgets('an unresolved entitlement (tier defaults to pro, fail-open) still shows the '
        'normal purchase flow', (tester) async {
      final now = DateTime.now();
      final unresolved = Entitlement(
        tier: EntitlementTier.pro, // fail-open default
        source: EntitlementSource.none,
        adsEnabled: false,
        historyDays: null,
        aiCreditsRemaining: null,
        trainer: null,
        expiresAt: null,
        checkedAt: now,
        graceUntil: now,
        degraded: false,
        resolved: false, // <- the point of this test
      );

      await _pumpPaywall(tester, trigger: PaywallTrigger.settings, entitlement: unresolved);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.paywallSponsoredHeadline), findsNothing);
      expect(find.text(l10n.paywallAlreadyProHeadline), findsNothing);
      expect(find.text(l10n.paywallPlanMonthlyLabel), findsOneWidget);
    });
  });

  group('320 pt width layout (golden-free)', () {
    testWidgets('renders without overflow, and drops the benefit description lines',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpPaywall(tester, trigger: PaywallTrigger.historyRange);

      expect(tester.takeException(), isNull);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Compact mode (69 §3.1: "the benefit sub-lines drop") — the headline
      // and CTA are still present...
      expect(find.text(l10n.paywallHeadlineHistoryRange), findsOneWidget);
      // ...but each benefit's description line is gone.
      expect(find.text(l10n.paywallBenefitNoAdsDescription), findsNothing);
      expect(find.text(l10n.paywallBenefitFullHistoryDescription), findsNothing);
      expect(find.text(l10n.paywallBenefitUnlimitedAiDescription), findsNothing);
    });
  });

  group('products unavailable (69 §3.3)', () {
    testWidgets('an empty product list shows the unavailable state, never a fabricated price',
        (tester) async {
      await _pumpPaywall(tester, trigger: PaywallTrigger.settings, products: const []);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.paywallUnavailableMessage), findsOneWidget);
      expect(find.text(l10n.paywallRetryButton), findsOneWidget);
      expect(find.text(l10n.paywallPlanMonthlyLabel), findsNothing);
    });
  });
}
