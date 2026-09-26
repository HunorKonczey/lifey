import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/theme/app_theme.dart';
import 'package:lifey/l10n/app_localizations.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';
import 'package:lifey/features/workouts/presentation/widgets/exercise_session_card.dart';
import 'package:lifey/features/workouts/presentation/widgets/workout_success_sheet.dart';
import 'package:lifey/features/workouts/domain/personal_record.dart';
import 'package:lifey/l10n/app_localizations_en.dart';

/// Covers [computeWorkoutProgress]'s PR integration
/// (docs/38-personal-records-plan.md, M4): a session's earned [SetRow.prTypes]
/// must surface as [WorkoutProgressResult.records], and any PR alone must
/// trigger [WorkoutProgressResult.isSuccess] regardless of the regular
/// improvement score.
void main() {
  final l10n = AppLocalizationsEn();
  final now = DateTime(2026, 7, 15, 10);

  ExerciseBlock blockWith({
    required String exerciseName,
    required List<SetRow> rows,
    List<PreviousSetHint> previousSets = const [],
  }) {
    final block = ExerciseBlock(
      exerciseClientId: exerciseName,
      exerciseName: exerciseName,
      rows: rows,
    );
    block.previousSets = previousSets;
    return block;
  }

  test('no PR flags on any row -> no records, isSuccess follows score only', () {
    final block = blockWith(
      exerciseName: 'Bench Press',
      rows: [SetRow(weight: 80, reps: 8, doneAt: now)],
    );

    final result = computeWorkoutProgress([block], l10n);

    expect(result.records, isEmpty);
    expect(result.isSuccess, isFalse);
  });

  test('a row with PR flags becomes a record row with matching chips', () {
    final row = SetRow(weight: 105, reps: 5, doneAt: now)
      ..prTypes = {PrType.maxWeight, PrType.estimatedOneRm};
    final block = blockWith(exerciseName: 'Squat', rows: [row]);

    final result = computeWorkoutProgress([block], l10n);

    expect(result.records, hasLength(1));
    expect(result.records.single.exerciseName, 'Squat');
    expect(result.records.single.chips, containsAll(['105 kg', 'e1RM ${_e1rm(105, 5)} kg']));
    expect(result.totalPrCount, 2);
  });

  test('a lone PR makes the session a success even with a flat score', () {
    final row = SetRow(weight: 60, reps: 12, doneAt: now)
      ..prTypes = {PrType.repsAtWeight};
    final block = blockWith(
      exerciseName: 'Leg Press',
      rows: [row],
      // No previous-performance hint at this index, so the regular
      // improvement score contribution for this row is zero.
      previousSets: const [],
    );

    final result = computeWorkoutProgress([block], l10n);

    expect(result.score, 0);
    expect(result.records, hasLength(1));
    expect(result.isSuccess, isTrue);
  });

  test('a not-done row is never counted as a record even if flagged', () {
    final row = SetRow(weight: 80, reps: 8)..prTypes = {PrType.maxWeight};
    final block = blockWith(exerciseName: 'Bench Press', rows: [row]);

    final result = computeWorkoutProgress([block], l10n);

    expect(result.records, isEmpty);
  });

  test('multiple PR-earning rows across exercises each contribute their own record row', () {
    final benchRow = SetRow(weight: 100, reps: 5, doneAt: now)
      ..prTypes = {PrType.maxWeight};
    final squatRow = SetRow(weight: 140, reps: 3, doneAt: now)
      ..prTypes = {PrType.estimatedOneRm};

    final result = computeWorkoutProgress([
      blockWith(exerciseName: 'Bench Press', rows: [benchRow]),
      blockWith(exerciseName: 'Squat', rows: [squatRow]),
    ], l10n);

    expect(result.records, hasLength(2));
    expect(result.totalPrCount, 2);
  });

  group('record entries', () {
    test('the delta is measured against the exercise baseline', () {
      final row = SetRow(weight: 50, reps: 8, doneAt: now)
        ..prTypes = {PrType.maxWeight, PrType.estimatedOneRm};
      final block = blockWith(exerciseName: 'Bench Press', rows: [row])
        ..prBaseline = PrBaseline.fromSets([(weight: 47.5, reps: 8, performedAt: DateTime(2026, 9, 1))]);

      final entries = computeWorkoutProgress([block], l10n).records.single.entries;

      expect(entries.map((e) => e.type), [PrType.maxWeight, PrType.estimatedOneRm]);
      expect(entries[0].value, 50);
      expect(entries[0].delta, closeTo(2.5, 1e-9));
      expect(entries[1].value, closeTo(50 * (1 + 8 / 30), 1e-9));
      expect(entries[1].delta, closeTo(2.5 * (1 + 8 / 30), 1e-9));
    });

    test('a reps record compares with the most reps at that exact weight', () {
      final row = SetRow(weight: 60, reps: 12, doneAt: now)..prTypes = {PrType.repsAtWeight};
      final block = blockWith(exerciseName: 'Leg Press', rows: [row])
        ..prBaseline = PrBaseline.fromSets([(weight: 60, reps: 10, performedAt: DateTime(2026, 9, 1))]);

      final entry = computeWorkoutProgress([block], l10n).records.single.entries.single;

      expect(entry.value, 12);
      expect(entry.delta, 2);
    });

    test('no delta without an earlier record to beat', () {
      final row = SetRow(weight: 60, reps: 12, doneAt: now)..prTypes = {PrType.maxWeight};
      final entry = computeWorkoutProgress([blockWith(exerciseName: 'New lift', rows: [row])], l10n)
          .records
          .single
          .entries
          .single;

      expect(entry.delta, isNull);
    });

    test('sets that each beat the old record collapse to the best one', () {
      final first = SetRow(weight: 50, reps: 8, doneAt: now)..prTypes = {PrType.maxWeight};
      final second = SetRow(weight: 52.5, reps: 6, doneAt: now)..prTypes = {PrType.maxWeight};
      final block = blockWith(exerciseName: 'Bench Press', rows: [first, second])
        ..prBaseline = PrBaseline.fromSets([(weight: 47.5, reps: 8, performedAt: DateTime(2026, 9, 1))]);

      final result = computeWorkoutProgress([block], l10n);

      expect(result.records.single.entries.single.value, 52.5);
      expect(result.records.single.entries.single.delta, closeTo(5, 1e-9));
      expect(result.totalPrCount, 2); // the chips stay one per set
      expect(result.recordEntryCount, 1);
    });
  });

  test('improvements carry the top weight and the biggest single-set gain', () {
    final block = blockWith(
      exerciseName: 'Overhead Press',
      rows: [
        SetRow(weight: 32.5, reps: 8, doneAt: now),
        SetRow(weight: 35, reps: 8, doneAt: now),
      ],
      previousSets: const [
        PreviousSetHint(weight: 30, reps: 8),
        PreviousSetHint(weight: 32.5, reps: 8),
      ],
    );

    final improvement = computeWorkoutProgress([block], l10n).improvements.single;

    expect(improvement.topWeight, 35);
    expect(improvement.bestWeightGain, 2.5);
    expect(improvement.bestRepsGain, 0);
  });

  test('the volume is the sum of weight x reps of the done sets', () {
    final block = blockWith(exerciseName: 'Bench Press', rows: [
      SetRow(weight: 50, reps: 8, doneAt: now),
      SetRow(weight: 60, reps: 5, doneAt: now),
      SetRow(weight: 100, reps: 10), // not done
    ]);

    expect(computeWorkoutVolume([block]), 700);
  });

  group('sheet', () {
    Future<void> pumpSheet(
      WidgetTester tester,
      WorkoutProgressResult result, {
      WorkoutSummary? summary,
      Locale locale = const Locale('en'),
      double width = 411,
      double textScale = 1,
      bool reduceMotion = false,
      ThemeData? theme,
    }) async {
      tester.view.physicalSize = Size(width * 2.625, 923 * 2.625);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: theme ?? AppTheme.dark,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showWorkoutSuccessSheet(context, result, summary: summary),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pump();
    }

    WorkoutProgressResult twoRecords() => computeWorkoutProgress([
          blockWith(
            exerciseName: 'Bench Press',
            rows: [
              SetRow(weight: 50, reps: 8, doneAt: now)..prTypes = {PrType.maxWeight, PrType.estimatedOneRm},
            ],
            previousSets: const [PreviousSetHint(weight: 47.5, reps: 8)],
          )..prBaseline = PrBaseline.fromSets([(weight: 47.5, reps: 8, performedAt: DateTime(2026, 9, 1))]),
          blockWith(
            exerciseName: 'Overhead Press',
            rows: [SetRow(weight: 35, reps: 8, doneAt: now)],
            previousSets: const [PreviousSetHint(weight: 32.5, reps: 8)],
          ),
        ], l10n);

    testWidgets('the canvas sheet: trophy, count, summary, record and improvement rows', (tester) async {
      await pumpSheet(
        tester,
        twoRecords(),
        summary: const WorkoutSummary(title: 'Push day', duration: Duration(minutes: 58), volume: 4280),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.emoji_events_rounded), findsNWidgets(3)); // hero + two record rows
      expect(find.text('2 new personal records'), findsOneWidget);
      expect(find.text('Push day · 58 min · 4,280 kg volume'), findsOneWidget);
      expect(find.text('Bench Press'), findsNWidgets(2));
      expect(find.text('Heaviest set'), findsOneWidget);
      expect(find.text('Estimated 1RM'), findsOneWidget);
      expect(find.text('50 kg'), findsOneWidget);
      expect(find.text('+2.5 kg'), findsNWidgets(2)); // heaviest set and the press
      expect(find.text('Overhead Press'), findsOneWidget);
      expect(find.text('Better than last time'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('without a personal record: no trophy, the plain done state', (tester) async {
      final result = computeWorkoutProgress([
        blockWith(
          exerciseName: 'Row',
          rows: [SetRow(weight: 60, reps: 10, doneAt: now), SetRow(weight: 62.5, reps: 10, doneAt: now)],
          previousSets: const [PreviousSetHint(weight: 57.5, reps: 8), PreviousSetHint(weight: 60, reps: 8)],
        ),
      ], l10n);
      expect(result.records, isEmpty);
      expect(result.isSuccess, isTrue);

      await pumpSheet(tester, result);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.emoji_events_rounded), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('Great workout!'), findsOneWidget);
      expect(find.text('Better than last time'), findsOneWidget);
    });

    testWidgets('a reps record reads "12 reps" with its gain', (tester) async {
      final row = SetRow(weight: 60, reps: 12, doneAt: now)..prTypes = {PrType.repsAtWeight};
      final result = computeWorkoutProgress([
        blockWith(exerciseName: 'Leg Press', rows: [row])
          ..prBaseline = PrBaseline.fromSets([(weight: 60, reps: 10, performedAt: DateTime(2026, 9, 1))]),
      ], l10n);

      await pumpSheet(tester, result);
      await tester.pumpAndSettle();

      expect(find.text('1 new personal record'), findsOneWidget);
      expect(find.text('Most reps at 60 kg'), findsOneWidget);
      expect(find.text('12 reps'), findsOneWidget);
      expect(find.text('+2 reps'), findsOneWidget);
    });

    testWidgets('the entrance plays once: rows start hidden, settle, then stay put', (tester) async {
      await pumpSheet(tester, twoRecords());

      double rowOpacity() {
        final opacity = tester.widget<Opacity>(
          find.ancestor(of: find.text('Overhead Press'), matching: find.byType(Opacity)).first,
        );
        return opacity.opacity;
      }

      expect(rowOpacity(), 0);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(rowOpacity(), 1);

      await tester.pump(const Duration(seconds: 2));
      expect(rowOpacity(), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion: everything is in place at once', (tester) async {
      await pumpSheet(tester, twoRecords(), reduceMotion: true);
      await tester.pump();

      final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.text('Overhead Press'), matching: find.byType(Opacity)).first,
      );
      expect(opacity.opacity, 1);
    });

    testWidgets('Continue closes the sheet', (tester) async {
      await pumpSheet(tester, twoRecords());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('2 new personal records'), findsNothing);
    });

    testWidgets('not a success: nothing opens', (tester) async {
      await pumpSheet(tester, const WorkoutProgressResult(score: 0, improvements: [], records: []));
      await tester.pumpAndSettle();

      expect(find.text('Continue'), findsNothing);
    });

    for (final width in [411.0, 360.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('no overflow at ${width.toInt()} dp, text x$scale, HU, light', (tester) async {
          await pumpSheet(
            tester,
            twoRecords(),
            summary: const WorkoutSummary(title: 'Nyomó nap', duration: Duration(minutes: 58), volume: 4280),
            locale: const Locale('hu'),
            width: width,
            textScale: scale,
            theme: AppTheme.light,
          );
          await tester.pumpAndSettle();

          final error = tester.takeException();
          expect(error is FlutterError ? error.toStringDeep() : error, isNull);
          expect(find.text('2 új egyéni rekord'), findsOneWidget);
        });
      }
    }
  });
}

String _e1rm(double weight, int reps) {
  final value = weight * (1 + reps / 30);
  return value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}
