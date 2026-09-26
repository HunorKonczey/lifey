import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/core/theme/app_tokens.dart';
import 'package:lifey/features/trainer/clients/domain/trainer_client.dart';
import 'package:lifey/features/trainer/clients/presentation/widgets/client_card.dart';
import 'package:lifey/features/trainer/clients/presentation/widgets/weight_sparkline.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/shared/widgets/ds/delta_chip.dart';

final _now = DateTime.utc(2026, 9, 25, 12);

TrainerClient _client({
  int workoutsPerWeek = 6,
  DateTime? lastActivityAt,
  DateTime? lastWeightAt,
  int missed = 0,
  int? avgCalories,
  int? prs,
  List<double> weights = const [],
}) =>
    TrainerClient(
      userId: 7,
      email: 'anna@example.com',
      firstName: 'Anna',
      lastName: 'Kovacs',
      activeSince: DateTime.utc(2026, 6, 1),
      workoutsPerWeek: workoutsPerWeek,
      lastActivityAt: lastActivityAt ?? _now,
      lastWeightAt: lastWeightAt ?? DateTime.utc(2026, 9, 24),
      missedWorkoutCount: missed,
      avgCalories7d: avgCalories,
      prCount7d: prs,
      weightTrend: [
        for (final (i, w) in weights.indexed) WeightTrendPoint(date: DateTime.utc(2026, 9, 10 + i), weightKg: w),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  TrainerClient client, {
  Locale locale = const Locale('en'),
  double textScale = 1,
  Size size = const Size(390, 900),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme ?? AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(20), child: ClientCard(client: client, now: _now)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('the client card (canvas 9.1)', () {
    testWidgets('an active client with everything: status, three KPIs, the sparkline and the PR chip', (tester) async {
      await _pump(tester, _client(avgCalories: 1631, prs: 2, weights: [65.9, 65.2, 64.5]));

      expect(find.text('Anna Kovacs'), findsOneWidget);
      expect(find.text('Active today'), findsOneWidget);
      expect(find.text('Avg kcal'), findsOneWidget);
      expect(find.text('1,631'), findsOneWidget);
      expect(find.text('6 / wk'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('−1.4 kg'), findsOneWidget);
      expect(find.byType(WeightSparkline), findsOneWidget);
      expect(find.byType(RecordChip), findsOneWidget);
      expect(find.text('2 PRs this week'), findsOneWidget);
    });

    testWidgets('a KPI with no figure is hidden, not drawn as zero', (tester) async {
      await _pump(tester, _client(avgCalories: null, weights: const [64.0]));

      expect(find.text('Avg kcal'), findsNothing); // no meals logged
      expect(find.text('Weight'), findsNothing); // one weigh-in is not a change
      expect(find.text('Workouts'), findsOneWidget);
      expect(find.byType(WeightSparkline), findsNothing);
    });

    testWidgets('zero records draws no chip, one reads in the singular', (tester) async {
      await _pump(tester, _client(prs: 0));
      expect(find.byType(RecordChip), findsNothing);

      await _pump(tester, _client(prs: 1));
      expect(find.text('1 PR this week'), findsOneWidget);
    });

    testWidgets('a quiet client reads "Last seen N days ago" and is flagged by the warning colour, not a chip',
        (tester) async {
      await _pump(tester, _client(lastActivityAt: _now.subtract(const Duration(days: 4))));

      expect(find.text('Last seen 4 days ago'), findsOneWidget);
      final dot = tester
          .widgetList<Container>(find.byType(Container))
          .firstWhere((c) => c.constraints?.maxWidth == 8 && c.decoration is BoxDecoration);
      final context = tester.element(find.text('Last seen 4 days ago'));
      expect((dot.decoration! as BoxDecoration).color, context.metricColors.calories);
      // ...and there is no separate "no log for 4 days" chip saying it again.
      expect(find.text('4d'), findsNothing);
    });

    testWidgets('yesterday is "Active yesterday", not "last seen"', (tester) async {
      await _pump(tester, _client(lastActivityAt: _now.subtract(const Duration(days: 1))));

      expect(find.text('Active yesterday'), findsOneWidget);
    });

    testWidgets('missed sessions and a stale weigh-in are chips of their own', (tester) async {
      await _pump(tester, _client(missed: 2, lastWeightAt: _now.subtract(const Duration(days: 9))));

      expect(find.text('Missed 2 sessions'), findsOneWidget);
      expect(find.text('Weigh-in due'), findsOneWidget);
    });

    testWidgets('a client who has never logged anything says so', (tester) async {
      final client = TrainerClient(userId: 9, email: 'new@example.com', activeSince: DateTime.utc(2026, 9, 24));
      await _pump(tester, client);

      expect(find.text('No activity yet'), findsOneWidget);
    });

    testWidgets('a long Hungarian status wraps beside the sparkline instead of ending in an ellipsis', (tester) async {
      await _pump(
        tester,
        _client(lastActivityAt: _now.subtract(const Duration(days: 3)), weights: [64.0, 64.3, 65.0]),
        locale: const Locale('hu'),
        textScale: 1.3,
        size: const Size(360, 900),
      );

      final status = find.textContaining('napja');
      expect(status, findsOneWidget);
      // (The test host's font is wider than the real one, so the rule is asserted, not a line count.)
      final text = tester.widget<Text>(status);
      expect(text.maxLines, 2);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(tester.takeException(), isNull);
    });

    for (final (name, locale) in [('English', const Locale('en')), ('Hungarian', const Locale('hu'))]) {
      for (final (mode, theme) in [('dark', AppTheme.dark), ('light', AppTheme.light)]) {
        testWidgets('fits 360 dp at × 1.3 in $name, $mode, with everything on it', (tester) async {
          await _pump(
            tester,
            _client(avgCalories: 2204, prs: 3, missed: 2, lastWeightAt: DateTime.utc(2026, 9, 1), weights: [64.0, 64.3, 65.0]),
            locale: locale,
            textScale: 1.3,
            size: const Size(360, 900),
            theme: theme,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
