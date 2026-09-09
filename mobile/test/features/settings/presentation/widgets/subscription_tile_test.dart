import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifey/core/entitlements/entitlement.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/features/settings/presentation/widgets/subscription_tile.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// Covers Prompt 7's own verify line: a widget test per state, in both
/// locales (`docs/landing_page/67-mobile-free-pro-plan.md` §4.4, `69` frame
/// P14).

Entitlement _entitlement({
  required EntitlementTier tier,
  required EntitlementSource source,
  DateTime? expiresAt,
  TrainerBillingEntitlement? trainer,
}) {
  final now = DateTime.now();
  return Entitlement(
    tier: tier,
    source: source,
    adsEnabled: tier == EntitlementTier.free,
    historyDays: tier == EntitlementTier.free ? 30 : null,
    aiCreditsRemaining: tier == EntitlementTier.free ? 3 : null,
    trainer: trainer,
    expiresAt: expiresAt,
    checkedAt: now,
    graceUntil: now.add(const Duration(days: 7)),
    degraded: false,
    resolved: true,
  );
}

Future<void> _pumpTile(WidgetTester tester, {Entitlement? entitlement, required Locale locale}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: SubscriptionTile(entitlement: entitlement)),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const Scaffold(body: Text('paywall')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in [const Locale('en'), const Locale('hu')]) {
    final isHu = locale.languageCode == 'hu';

    group('locale: ${locale.languageCode}', () {
      testWidgets('free: shows the Lifey Pro upsell and opens the paywall on tap', (tester) async {
        await _pumpTile(tester, entitlement: null, locale: locale);
        final l10n = await AppLocalizations.delegate.load(locale);

        expect(find.text(l10n.lifeyProLabel), findsOneWidget);
        expect(find.text(l10n.settingsSubscriptionFreeSubtitle), findsOneWidget);
        expect(find.text(l10n.paywallRestoreButton), findsOneWidget);

        await tester.tap(find.text(l10n.lifeyProLabel));
        await tester.pumpAndSettle();
        expect(find.text('paywall'), findsOneWidget);
      });

      testWidgets('own purchase (appStore): shows "Pro · renews {date}", chevron, and restore',
          (tester) async {
        final entitlement = _entitlement(
          tier: EntitlementTier.pro,
          source: EntitlementSource.appStore,
          expiresAt: DateTime(2026, 9, 12),
        );
        await _pumpTile(tester, entitlement: entitlement, locale: locale);
        final l10n = await AppLocalizations.delegate.load(locale);

        expect(find.text(l10n.settingsSubscriptionProTitle), findsOneWidget);
        // Exact date formatting is locale-engine-dependent (DateFormat.yMMMd)
        // — check the fixed prefix rather than the full rendered string.
        expect(find.textContaining(isHu ? 'Megújul' : 'Renews'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
        expect(find.text(l10n.paywallRestoreButton), findsOneWidget);
      });

      testWidgets('sponsored: shows "Pro — included by your trainer", no CTA, no restore',
          (tester) async {
        final entitlement = _entitlement(
          tier: EntitlementTier.pro,
          source: EntitlementSource.trainerSponsored,
        );
        await _pumpTile(tester, entitlement: entitlement, locale: locale);
        final l10n = await AppLocalizations.delegate.load(locale);

        expect(find.text(l10n.settingsSubscriptionProTitle), findsOneWidget);
        expect(find.text(l10n.settingsSubscriptionSponsoredSubtitle), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsNothing);
        expect(find.text(l10n.paywallRestoreButton), findsNothing);
      });

      testWidgets('trainer trial: shows "Trainer trial · N days left", links to web billing',
          (tester) async {
        final now = DateTime.now();
        final entitlement = _entitlement(
          tier: EntitlementTier.pro,
          source: EntitlementSource.trainerTrial,
          trainer: TrainerBillingEntitlement(
            plan: 'PRO',
            status: 'TRIALING',
            maxClients: 5,
            activeClients: 2,
            trialEndsAt: DateTime(now.year, now.month, now.day).add(const Duration(days: 6)),
          ),
        );
        await _pumpTile(tester, entitlement: entitlement, locale: locale);
        final l10n = await AppLocalizations.delegate.load(locale);

        expect(find.text(l10n.settingsSubscriptionTrialTitle), findsOneWidget);
        expect(find.text(l10n.settingsSubscriptionTrialDaysLeft(6)), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
        // No restore for a trainer trial — there's no purchase to restore.
        expect(find.text(l10n.paywallRestoreButton), findsNothing);
      });
    });
  }

  group('SubscriptionSection', () {
    testWidgets(
        'an unresolved entitlement (fail-open, tier == pro) still renders the free tile, '
        'not a false Pro claim (D-P4)', (tester) async {
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            entitlementProvider.overrideWith(() => _FakeEntitlementController(unresolved)),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SubscriptionSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.lifeyProLabel), findsOneWidget);
      expect(find.text(l10n.settingsSubscriptionProTitle), findsNothing);
    });
  });
}

class _FakeEntitlementController extends EntitlementController {
  _FakeEntitlementController(this._entitlement);
  final Entitlement _entitlement;

  @override
  Stream<Entitlement> build() => Stream.value(_entitlement);
}
