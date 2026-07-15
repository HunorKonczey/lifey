import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';
import 'package:lifey/features/workouts/presentation/widgets/exercise_session_card.dart';
import 'package:lifey/features/workouts/presentation/widgets/workout_success_dialog.dart';
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
}

String _e1rm(double weight, int reps) {
  final value = weight * (1 + reps / 30);
  return value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}
