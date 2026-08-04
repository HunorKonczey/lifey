import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/workouts/presentation/watch_set_log_decision.dart';
import 'package:lifey/features/workouts/data/workout_session_repository.dart';
import 'package:lifey/features/workouts/presentation/widgets/exercise_session_card.dart';

ExerciseBlock _block(String id, {required List<bool> doneRows}) => ExerciseBlock(
      exerciseClientId: id,
      exerciseName: id,
      rows: [for (final done in doneRows) SetRow(doneAt: done ? DateTime(2026) : null)],
    );

WatchSetLogDecision _decide({
  String eventSessionClientId = 'session-1',
  String? currentSessionClientId = 'session-1',
  bool sessionFinished = false,
  bool saving = false,
  String eventId = 'event-1',
  List<String> recentEventIds = const [],
  required List<ExerciseBlock> blocks,
  ExerciseBlock? currentBlock,
}) =>
    decideWatchSetLog(
      eventSessionClientId: eventSessionClientId,
      currentSessionClientId: currentSessionClientId,
      sessionFinished: sessionFinished,
      saving: saving,
      eventId: eventId,
      recentEventIds: recentEventIds,
      blocks: blocks,
      currentBlock: currentBlock,
    );

void main() {
  group('decideWatchSetLog — guards', () {
    test('session-id mismatch rejects', () {
      final block = _block('a', doneRows: [false]);
      final decision = _decide(
        eventSessionClientId: 'session-1',
        currentSessionClientId: 'session-2',
        blocks: [block],
        currentBlock: block,
      );
      expect(decision.action, WatchSetLogAction.reject);
    });

    test('no active session (null) rejects', () {
      final block = _block('a', doneRows: [false]);
      final decision = _decide(
        currentSessionClientId: null,
        blocks: [block],
        currentBlock: block,
      );
      expect(decision.action, WatchSetLogAction.reject);
    });

    test('finished session rejects', () {
      final block = _block('a', doneRows: [false]);
      final decision = _decide(
        sessionFinished: true,
        blocks: [block],
        currentBlock: block,
      );
      expect(decision.action, WatchSetLogAction.reject);
    });

    test('mid-save rejects', () {
      final block = _block('a', doneRows: [false]);
      final decision = _decide(
        saving: true,
        blocks: [block],
        currentBlock: block,
      );
      expect(decision.action, WatchSetLogAction.reject);
    });

    test('no blocks at all rejects', () {
      final decision = _decide(blocks: [], currentBlock: null);
      expect(decision.action, WatchSetLogAction.reject);
    });
  });

  group('decideWatchSetLog — dedup', () {
    test('a previously-seen eventId dedupes instead of logging again', () {
      final block = _block('a', doneRows: [false]);
      final decision = _decide(
        eventId: 'event-1',
        recentEventIds: ['event-0', 'event-1', 'event-2'],
        blocks: [block],
        currentBlock: block,
      );
      expect(decision.action, WatchSetLogAction.dedupe);
      expect(decision.target, isNull);
    });

    test('the same tap delivered twice: first logs, second (same eventId) dedupes', () {
      final block = _block('a', doneRows: [false]);
      final first = _decide(eventId: 'event-1', recentEventIds: const [], blocks: [block], currentBlock: block);
      expect(first.action, WatchSetLogAction.log);

      // Screen would append 'event-1' to its FIFO after handling `first`.
      final second = _decide(eventId: 'event-1', recentEventIds: const ['event-1'], blocks: [block], currentBlock: block);
      expect(second.action, WatchSetLogAction.dedupe);
    });
  });

  group('decideWatchSetLog — row selection', () {
    test('rule 1: logs the current block\'s first not-done row', () {
      final current = _block('current', doneRows: [true, false, false]);
      final other = _block('other', doneRows: [false]);
      final decision = _decide(blocks: [other, current], currentBlock: current);

      expect(decision.action, WatchSetLogAction.log);
      expect(decision.target!.blockIndex, 1);
      expect(decision.target!.rowIndex, 1);
      expect(decision.target!.needsNewRow, isFalse);
    });

    test('rule 2: current block fully done — falls to the first block (in list order) with a not-done row', () {
      final current = _block('current', doneRows: [true, true]);
      final earlier = _block('earlier', doneRows: [true, false]);
      final later = _block('later', doneRows: [false]);
      final decision = _decide(blocks: [earlier, current, later], currentBlock: current);

      expect(decision.action, WatchSetLogAction.log);
      expect(decision.target!.blockIndex, 0);
      expect(decision.target!.rowIndex, 1);
      expect(decision.target!.needsNewRow, isFalse);
    });

    test('rule 2 with no current block: still finds the first block with a not-done row', () {
      final a = _block('a', doneRows: [true]);
      final b = _block('b', doneRows: [true, false]);
      final decision = _decide(blocks: [a, b], currentBlock: null);

      expect(decision.action, WatchSetLogAction.log);
      expect(decision.target!.blockIndex, 1);
      expect(decision.target!.rowIndex, 1);
    });

    test('rule 3: every row everywhere is done — appends a new row to the current block', () {
      final current = _block('current', doneRows: [true, true]);
      final other = _block('other', doneRows: [true]);
      final decision = _decide(blocks: [other, current], currentBlock: current);

      expect(decision.action, WatchSetLogAction.log);
      expect(decision.target!.blockIndex, 1);
      expect(decision.target!.needsNewRow, isTrue);
      expect(decision.target!.rowIndex, isNull);
    });

    test('rule 3 with no current block: appends to the first block', () {
      final a = _block('a', doneRows: [true]);
      final b = _block('b', doneRows: [true]);
      final decision = _decide(blocks: [a, b], currentBlock: null);

      expect(decision.action, WatchSetLogAction.log);
      expect(decision.target!.blockIndex, 0);
      expect(decision.target!.needsNewRow, isTrue);
    });
  });
  _prefillTests();
}

// ---------------------------------------------------------------------------
// F5b — prefill (docs/watch/48-watch-f5b-set-adjust-plan.md D-F5b.2)
// ---------------------------------------------------------------------------

ExerciseBlock _blockWithRows(
  String id, {
  required List<SetRow> rows,
  List<PreviousSetHint> previousSets = const [],
}) {
  final block = ExerciseBlock(exerciseClientId: id, exerciseName: id, rows: rows);
  block.previousSets = previousSets;
  return block;
}

SetRow _row({double? weight, int? reps, bool done = false}) =>
    SetRow(weight: weight, reps: reps, doneAt: done ? DateTime(2026) : null);

void _prefillTests() {
  group('watchSetPrefill — D-F5b.2 prioritás', () {
    test('1. a cél-sor saját értéke nyer, ha mindkettő ki van töltve', () {
      final block = _blockWithRows(
        'a',
        rows: [_row(weight: 50, reps: 8, done: true), _row(weight: 60, reps: 10)],
        // A previousSets szándékosan mást mond — a sor értékének kell nyernie.
        previousSets: const [
          PreviousSetHint(weight: 1, reps: 1),
          PreviousSetHint(weight: 2, reps: 2),
        ],
      );

      final prefill = watchSetPrefill([block], block);

      expect(prefill!.weight, 60);
      expect(prefill.reps, 10);
    });

    test('2. üres cél-sor → az előző teljesítmény ugyanarra a pozícióra', () {
      final block = _blockWithRows(
        'a',
        rows: [_row(weight: 50, reps: 8, done: true), _row()],
        previousSets: const [
          PreviousSetHint(weight: 55, reps: 9),
          PreviousSetHint(weight: 62.5, reps: 6),
        ],
      );

      final prefill = watchSetPrefill([block], block);

      expect(prefill!.weight, 62.5, reason: 'az 1-es indexű előzményt kell venni, nem a 0-ást');
      expect(prefill.reps, 6);
    });

    test('2b. félig kitöltött cél-sor nem nyer — átesik az előzményre', () {
      final block = _blockWithRows(
        'a',
        rows: [_row(reps: 12)], // súly hiányzik
        previousSets: const [PreviousSetHint(weight: 40, reps: 5)],
      );

      final prefill = watchSetPrefill([block], block);

      expect(prefill!.weight, 40);
      expect(prefill.reps, 5);
    });

    test('3. nincs előzmény → a blokk utolsó kész sora', () {
      final block = _blockWithRows(
        'a',
        rows: [
          _row(weight: 40, reps: 12, done: true),
          _row(weight: 45, reps: 10, done: true),
          _row(),
        ],
      );

      final prefill = watchSetPrefill([block], block);

      expect(prefill!.weight, 45, reason: 'az utolsó kész sor, nem az első');
      expect(prefill.reps, 10);
    });

    test('4. semmi támpont → null', () {
      final block = _blockWithRows('a', rows: [_row()]);

      expect(watchSetPrefill([block], block), isNull);
    });

    test('nincs blokk → null', () {
      expect(watchSetPrefill(const [], null), isNull);
    });

    test('minden sor kész → az új sor pozíciójára néz előzményt (rule c + 2)', () {
      final block = _blockWithRows(
        'a',
        rows: [_row(weight: 50, reps: 8, done: true)],
        previousSets: const [
          PreviousSetHint(weight: 50, reps: 8),
          PreviousSetHint(weight: 52.5, reps: 7),
        ],
      );

      final prefill = watchSetPrefill([block], block);

      expect(prefill!.weight, 52.5, reason: 'a hozzáfűzendő sor indexe 1');
      expect(prefill.reps, 7);
    });

    test('egy tervezett üres sorra is van prefill — ez tölti ki az egy-koppintásos logot', () {
      // Az egy-koppintásos log korábban csak a doneAt-et bélyegezte rá a
      // tervezett (mindig üres) sorra, így érték nélküli szett keletkezett,
      // amit a mentés aztán el is dobott. A cél-sorra feloldott prefill az,
      // amit a telefon ilyenkor beír.
      final block = _blockWithRows(
        'a',
        rows: [_row(weight: 60, reps: 8, done: true), _row()],
        previousSets: const [
          PreviousSetHint(weight: 60, reps: 8),
          PreviousSetHint(weight: 62.5, reps: 6),
        ],
      );

      final target = selectWatchSetLogTarget([block], block);
      final prefill = watchSetPrefill([block], block);

      expect(target!.rowIndex, 1, reason: 'a tervezett üres sor a cél');
      expect(prefill, isNotNull, reason: 'van mit beírni — nem maradhat üres a sor');
      expect(prefill!.weight, 62.5);
      expect(prefill.reps, 6);
    });

    test('semmi előzmény és semmi kész sor → nincs prefill (az óra az adjustot nyitja)', () {
      // Ez az egyetlen eset, amikor az egy-koppintásos log nem tud mit
      // beírni — ilyenkor az órán a "+1" gomb a steppert nyitja meg helyette.
      final block = _blockWithRows('a', rows: [_row(), _row()]);

      expect(watchSetPrefill([block], block), isNull);
    });

    test('a prefill ugyanarra a sorra vonatkozik, amit a logolás célozna', () {
      final current = _blockWithRows('current', rows: [_row(weight: 50, reps: 8, done: true)]);
      final other = _blockWithRows('other', rows: [_row(weight: 70, reps: 5)]);

      // A cél a másik blokk nyitott sora (b szabály) — a prefillnek is azt kell látnia.
      final target = selectWatchSetLogTarget([other, current], current);
      final prefill = watchSetPrefill([other, current], current);

      expect(target!.blockIndex, 0);
      expect(target.rowIndex, 0);
      expect(prefill!.weight, 70);
      expect(prefill.reps, 5);
    });
  });

  group('watchCurrentBlock — az óra saját aktuális gyakorlata', () {
    final bench = _block('ex-bench', doneRows: [true, true, true]);
    final squat = _block('ex-squat', doneRows: [false, false]);
    const templateIds = ['ex-bench', 'ex-squat'];

    test('az óra indexe nyer a telefon "utoljára logolt" szabálya felett', () {
      // A telefon szerint a bench az aktuális (ott volt az utolsó szett), az
      // óra viszont már továbblépett a squatra — ez a hiba lényege.
      expect(watchCurrentBlock([bench, squat], templateIds, 1), squat);
    });

    test('a session gyakorlat-sorrendje eltérhet a template-étől', () {
      // Feloldás exerciseClientId szerint, nem pozíció szerint.
      expect(watchCurrentBlock([squat, bench], templateIds, 0), bench);
    });

    test('index nélkül (telefonról indított edzés) nincs felülbírálás', () {
      expect(watchCurrentBlock([bench, squat], templateIds, null), isNull);
    });

    test('betöltetlen template esetén nincs felülbírálás', () {
      expect(watchCurrentBlock([bench, squat], const [], 1), isNull);
    });

    test('a tervből kiesett indexre nem tippel', () {
      expect(watchCurrentBlock([bench, squat], templateIds, 5), isNull);
      expect(watchCurrentBlock([bench, squat], templateIds, -1), isNull);
    });

    test('a session-ben nem szereplő gyakorlatra nem tippel', () {
      expect(watchCurrentBlock([bench], templateIds, 1), isNull);
    });

    test('a prefill az óra gyakorlatához tartozik, nem a befejezetthez', () {
      final benchDone = _blockWithRows('ex-bench', rows: [_row(weight: 80, reps: 5, done: true)]);
      final squatOpen = _blockWithRows('ex-squat', rows: [_row(weight: 100, reps: 6)]);
      final blocks = [benchDone, squatOpen];

      final current = watchCurrentBlock(blocks, templateIds, 1);
      final prefill = watchSetPrefill(blocks, current);

      expect(prefill!.weight, 100);
      expect(prefill.reps, 6);
    });
  });
}
