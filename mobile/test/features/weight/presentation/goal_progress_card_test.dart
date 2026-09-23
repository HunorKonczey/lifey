import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/onboarding/data/user_details_repository.dart';
import 'package:lifey/features/onboarding/domain/user_details.dart';
import 'package:lifey/features/weight/application/weight_controller.dart';
import 'package:lifey/features/weight/domain/weight_entry.dart';
import 'package:lifey/features/weight/presentation/widgets/goal_progress_card.dart';
import 'package:lifey/l10n/app_localizations.dart';

/// The card's states (docs/76-smarter-weight-trend-plan.md §4), driven through
/// the real providers: goal from `/user-details`, weigh-ins from the local DB.

class _FakeWeights extends WeightController {
  _FakeWeights(this._entries);

  final List<WeightEntry> _entries;

  @override
  Stream<List<WeightEntry>> build() => Stream.value(_entries);
}

final _today = DateTime(2026, 3, 30);

UserDetails _details(double targetWeightKg) => UserDetails(
      gender: Gender.male,
      birthDate: DateTime(1995, 5, 5),
      heightCm: 182,
      activityLevel: ActivityLevel.moderate,
      primaryGoal: PrimaryGoal.loseWeight,
      targetWeightKg: targetWeightKg,
    );

/// Newest first, the order `WeightRepository.watchAll` emits.
List<WeightEntry> _dailyEntries(int days, {double from = 90, double kgPerDay = 0}) {
  return [
    for (var i = 0; i < days; i++)
      WeightEntry(
        clientId: 'w$i',
        weight: from + kgPerDay * (days - 1 - i),
        date: _today.subtract(Duration(days: i)),
        recordedAt: _today.subtract(Duration(days: i)),
      ),
  ];
}

Future<void> _pump(
  WidgetTester tester, {
  required List<WeightEntry> entries,
  double? goal,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      weightControllerProvider.overrideWith(() => _FakeWeights(entries)),
      userDetailsProvider.overrideWith((ref) async =>
          goal == null ? null : _details(goal)),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: GoalProgressCard()),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the goal, what is left and when it would be reached',
      (tester) async {
    await _pump(tester, entries: _dailyEntries(30, from: 90, kgPerDay: -0.1), goal: 82);

    expect(find.text('Goal weight'), findsOneWidget);
    expect(find.text('82.0 kg'), findsOneWidget);
    expect(find.textContaining('kg to go'), findsOneWidget);
    expect(find.textContaining('kg/week'), findsOneWidget);
    expect(find.textContaining('At this rate, around'), findsOneWidget);
  });

  testWidgets('says the goal is reached instead of counting down to it',
      (tester) async {
    await _pump(tester, entries: _dailyEntries(30, from: 80.1), goal: 80);

    expect(find.text("You're at your goal weight"), findsOneWidget);
    expect(find.textContaining('kg to go'), findsNothing);
  });

  testWidgets('calls out a trend moving the wrong way', (tester) async {
    await _pump(tester, entries: _dailyEntries(30, from: 90, kgPerDay: 0.1), goal: 80);

    expect(find.text('The trend is moving away from your goal'), findsOneWidget);
    expect(find.textContaining('At this rate, around'), findsNothing);
  });

  testWidgets('asks for more weigh-ins rather than guessing', (tester) async {
    await _pump(tester, entries: _dailyEntries(5, from: 90, kgPerDay: -0.1), goal: 80);

    expect(
        find.textContaining('Keep weighing in for a couple of weeks'), findsOneWidget);
    expect(find.textContaining('kg/week'), findsNothing);
  });

  testWidgets('without a goal weight there is no card at all', (tester) async {
    await _pump(tester, entries: _dailyEntries(30, from: 90, kgPerDay: -0.1));

    expect(find.byType(Card), findsNothing);
    expect(find.text('Goal weight'), findsNothing);
  });

  testWidgets('without any weigh-ins there is no card either', (tester) async {
    await _pump(tester, entries: const [], goal: 80);

    expect(find.text('Goal weight'), findsNothing);
  });
}
