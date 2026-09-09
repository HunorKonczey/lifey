import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/entitlements/sponsorship_notice.dart';
import 'package:lifey/features/dashboard/presentation/widgets/sponsorship_ended_card.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The card itself (`72` Prompt 10). Its *when* is covered by
/// `test/core/entitlements/sponsorship_notice_test.dart`; this is the *what*:
/// it says the data is safe, it offers no upsell, and it can be dismissed.

class _PendingNotice extends SponsorshipNoticeController {
  _PendingNotice(this._pending);
  final bool _pending;

  @override
  Future<bool> build() async => _pending;
}

Future<void> _pumpCard(WidgetTester tester, {required bool pending}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sponsorshipNoticeProvider.overrideWith(() => _PendingNotice(pending)),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SponsorshipEndedCard()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders nothing when there is no notice pending', (tester) async {
    await _pumpCard(tester, pending: false);

    expect(tester.getSize(find.byType(SponsorshipEndedCard)), Size.zero);
  });

  testWidgets('leads with the reassurance and offers no upsell (69 §12.1)', (tester) async {
    await _pumpCard(tester, pending: true);

    expect(find.text("Your coach's Pro has ended"), findsOneWidget);
    expect(
      find.text(
        'Your coaching relationship has ended, so the Pro features are switched off. '
        'Your data is all still here.',
      ),
      findsOneWidget,
    );
    // No CTA of any kind — the paywall is reachable again from its normal
    // entry points, and this card is not one of them.
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('dismissing hides it', (tester) async {
    await _pumpCard(tester, pending: true);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(SponsorshipEndedCard)), Size.zero);
  });
}
