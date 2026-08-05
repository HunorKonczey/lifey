import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';
import 'package:lifey/features/workouts/presentation/watch_session_plan.dart';
import 'package:lifey/features/workouts/presentation/widgets/exercise_session_card.dart';

ExerciseBlock _block(
  String id, {
  required List<SetRow> rows,
  List<PreviousSetHint> previousSets = const [],
}) {
  final block = ExerciseBlock(exerciseClientId: id, exerciseName: 'Név: $id', rows: rows);
  block.previousSets = previousSets;
  return block;
}

SetRow _row({bool done = false}) => SetRow(doneAt: done ? DateTime(2026) : null);

Map<String, Object?> _decode(String? json) =>
    jsonDecode(json!) as Map<String, Object?>;

List<Object?> _exercises(String? json) => _decode(json)['exercises'] as List<Object?>;

void main() {
  group('buildWatchSessionPlanJson', () {
    test('a session gyakorlatai sorrendben, a telefon pihenőidejével', () {
      final json = buildWatchSessionPlanJson(
        blocks: [
          _block('ex-bench', rows: [_row(done: true), _row()]),
          _block('ex-squat', rows: [_row()]),
        ],
        restSecondsFor: (block) => block.exerciseClientId == 'ex-bench' ? 90 : 120,
      );

      final exercises = _exercises(json).cast<Map<String, Object?>>();
      expect(exercises.map((e) => e['exerciseId']), ['ex-bench', 'ex-squat']);
      expect(exercises.first['name'], 'Név: ex-bench');
      expect(exercises.first['restSeconds'], 90);
      expect(exercises.last['restSeconds'], 120);
    });

    test('setsDone a kész sorokból, targetSets az élő sorszámból', () {
      // A "+ Add set" a telefonon megnöveli a sorok számát — az órán is
      // ennyinek kell látszania, nem a terv befagyott számának.
      final json = buildWatchSessionPlanJson(
        blocks: [
          _block('ex-bench', rows: [_row(done: true), _row(done: true), _row()]),
        ],
        restSecondsFor: (_) => 90,
      );

      final exercise = _exercises(json).first as Map<String, Object?>;
      expect(exercise['setsDone'], 2);
      expect(exercise['targetSets'], 3);
    });

    test('az előző edzés szettjei mennek a prefillhez', () {
      final json = buildWatchSessionPlanJson(
        blocks: [
          _block(
            'ex-bench',
            rows: [_row()],
            previousSets: const [
              PreviousSetHint(weight: 60, reps: 10),
              PreviousSetHint(weight: 55, reps: 12),
            ],
          ),
        ],
        restSecondsFor: (_) => 90,
      );

      final exercise = _exercises(json).first as Map<String, Object?>;
      expect(exercise['previousSets'], [
        {'weight': 60.0, 'reps': 10},
        {'weight': 55.0, 'reps': 12},
      ]);
    });

    test('a telefonon hozzáadott gyakorlat is benne van — ez az F6c lényege', () {
      final json = buildWatchSessionPlanJson(
        blocks: [
          _block('ex-bench', rows: [_row(done: true)]),
          _block('ex-uj', rows: [_row()]),
        ],
        restSecondsFor: (_) => 90,
      );

      expect(
        _exercises(json).cast<Map<String, Object?>>().map((e) => e['exerciseId']),
        contains('ex-uj'),
      );
    });

    test('üres kulcsok nem mennek ki, blokk nélkül nincs payload', () {
      final json = buildWatchSessionPlanJson(
        blocks: [_block('ex-bench', rows: const [])],
        restSecondsFor: (_) => 90,
      );

      final exercise = _exercises(json).first as Map<String, Object?>;
      expect(exercise.containsKey('targetSets'), isFalse,
          reason: 'sor nélküli blokk nem "kész", csak nincs cél-szettszáma');
      expect(exercise.containsKey('previousSets'), isFalse);

      expect(buildWatchSessionPlanJson(blocks: const [], restSecondsFor: (_) => 90), isNull);
    });
  });
}
