import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/sync/sync_status_provider.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/features/chat/application/chat_share.dart';
import 'package:lifey/features/chat/domain/chat_peer.dart';
import 'package:lifey/features/nutrition/domain/meal.dart';
import 'package:lifey/features/nutrition/presentation/widgets/meal_list_item.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// "Share in chat" in a meal's long-press menu (LIF-123): offered only with somebody to send it to - a row that can never work is
/// clutter, not information.
Meal _meal() => Meal(
      clientId: 'm1',
      dateTime: DateTime(2026, 10, 3, 12, 30),
      mealType: MealType.lunch,
      entries: const [
        MealEntry(foodClientId: 'a', foodName: 'Chicken', quantityInGrams: 150, calories: 250, protein: 40, carbs: 0, fat: 8),
      ],
    );

const _trainer = ChatShareTarget(
  peer: ChatPeer(userId: 9, displayName: 'Mark Trainer', email: 'mark@example.com', role: ChatPeerRole.trainer),
  conversationId: 4,
);

Future<void> _pump(WidgetTester tester, List<ChatShareTarget> targets) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        syncStatusByClientIdProvider.overrideWithValue(const {}),
        chatShareTargetsProvider.overrideWith((ref) async => targets),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MealListItem(meal: _meal())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the long-press menu offers sharing when there is somebody to share with', (tester) async {
    await _pump(tester, const [_trainer]);

    await tester.longPress(find.text('Lunch'));
    await tester.pumpAndSettle();

    expect(find.text('Share in chat'), findsOneWidget);
    // The other actions are where they were.
    expect(find.text('Duplicate'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('with nobody to share with the row is not there at all', (tester) async {
    await _pump(tester, const []);

    await tester.longPress(find.text('Lunch'));
    await tester.pumpAndSettle();

    expect(find.text('Share in chat'), findsNothing);
    expect(find.text('Duplicate'), findsOneWidget);
  });
}
