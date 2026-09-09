import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';
import 'package:lifey/features/nutrition/presentation/widgets/ai_credit_chip.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// Covers the AI credit chip (frame P13, `69` §4.3/DV-11/DV-12) at
/// 3/1/0 credits and `null` (unlimited), with the ICU-plural semantics
/// label verified in both locales — the explicit Prompt 4 verify item.

Future<ProviderContainer> _pumpChip(
  WidgetTester tester, {
  required int? credits,
  required Locale locale,
}) async {
  late ProviderContainer container;
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          container = ProviderScope.containerOf(context);
          return const Scaffold(body: Center(child: AiCreditChip()));
        },
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const Scaffold(body: Text('paywall')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [aiCreditsProvider.overrideWithValue(credits)],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  for (final locale in [const Locale('en'), const Locale('hu')]) {
    final isHu = locale.languageCode == 'hu';

    group('locale: ${locale.languageCode}', () {
      testWidgets('3 credits shows the bare number and the plural semantics label',
          (tester) async {
        await _pumpChip(tester, credits: 3, locale: locale);

        expect(find.text('3'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            isHu ? '3 AI kredited maradt ebben a hónapban' : '3 AI credits left this month',
          ),
          findsOneWidget,
        );
      });

      testWidgets('1 credit shows the bare number and the singular semantics label',
          (tester) async {
        await _pumpChip(tester, credits: 1, locale: locale);

        expect(find.text('1'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            isHu ? '1 AI kredited maradt ebben a hónapban' : '1 AI credit left this month',
          ),
          findsOneWidget,
        );
      });

      testWidgets('0 credits shows the refill date instead of "0", and the zero semantics label',
          (tester) async {
        await _pumpChip(tester, credits: 0, locale: locale);

        expect(find.text('0'), findsNothing);
        expect(
          find.textContaining(isHu ? 'Feltöltődik' : 'Refills'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            isHu ? 'Nincs AI kredited ebben a hónapban' : 'No AI credits left this month',
          ),
          findsOneWidget,
        );
      });

      testWidgets('0 credits stays tappable and opens the paywall (DV-12)', (tester) async {
        await _pumpChip(tester, credits: 0, locale: locale);

        await tester.tap(find.byType(AiCreditChip));
        await tester.pumpAndSettle();

        expect(find.text('paywall'), findsOneWidget);
      });

      testWidgets('null (unlimited: Pro, or unresolved and fail-open) renders nothing',
          (tester) async {
        await _pumpChip(tester, credits: null, locale: locale);

        expect(
          find.descendant(of: find.byType(AiCreditChip), matching: find.byType(Material)),
          findsNothing,
        );
      });
    });
  }
}
