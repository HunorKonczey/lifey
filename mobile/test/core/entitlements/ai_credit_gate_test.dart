import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lifey/core/entitlements/ai_credit_gate.dart';
import 'package:lifey/core/entitlements/entitlement_providers.dart';

void main() {
  Future<({BuildContext context, WidgetRef ref})> pumpHarness(
    WidgetTester tester, {
    required int? credits,
  }) async {
    late BuildContext capturedContext;
    late WidgetRef capturedRef;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Consumer(
            builder: (context, ref, _) {
              capturedContext = context;
              capturedRef = ref;
              return const Scaffold(body: SizedBox());
            },
          ),
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
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return (context: capturedContext, ref: capturedRef);
  }

  testWidgets('returns true and does not navigate when credits remain', (tester) async {
    final h = await pumpHarness(tester, credits: 3);

    expect(requireAiCredits(h.context, h.ref), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('paywall'), findsNothing);
  });

  testWidgets('returns true and does not navigate when unlimited (null)', (tester) async {
    final h = await pumpHarness(tester, credits: null);

    expect(requireAiCredits(h.context, h.ref), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('paywall'), findsNothing);
  });

  testWidgets('returns false and opens the paywall when credits are exhausted', (tester) async {
    final h = await pumpHarness(tester, credits: 0);

    expect(requireAiCredits(h.context, h.ref), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('paywall'), findsOneWidget);
  });
}
