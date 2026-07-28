import 'widgets/exercise_session_card.dart';

/// What [LogSessionScreen] should do with an incoming `WatchSetLogged` event
/// (docs/watch/43-watch-f5-set-logging-plan.md §5.2/3–4). Pulled out of the
/// screen as a pure, `BuildContext`-free function so the guard/dedup/
/// row-selection logic is unit-testable without mounting the whole screen.
enum WatchSetLogAction {
  /// Session mismatch, or the screen is finished/mid-save — ack `false`,
  /// nothing logged.
  reject,

  /// This [WatchSetLogged.eventId] was already handled (retried delivery) —
  /// ack `true` again without logging a second time.
  dedupe,

  /// Log the row named by [WatchSetLogDecision.target], then ack `true`.
  log,
}

/// Which row to mark done — an existing plan row, or (when every row in
/// every block is already done) a freshly added one at the end of
/// [blockIndex]'s block.
class WatchSetLogTarget {
  const WatchSetLogTarget({
    required this.blockIndex,
    this.rowIndex,
    this.needsNewRow = false,
  }) : assert(needsNewRow == (rowIndex == null));

  final int blockIndex;
  final int? rowIndex;
  final bool needsNewRow;
}

class WatchSetLogDecision {
  const WatchSetLogDecision({required this.action, this.target})
      : assert(action != WatchSetLogAction.log || target != null);

  final WatchSetLogAction action;
  final WatchSetLogTarget? target;
}

/// Which row the *next* watch "+1 set" tap would log into
/// (docs/watch/43-watch-f5-set-logging-plan.md §5.2/4):
///
/// a. [currentBlock]'s first not-done row, if any;
/// b. else the first block (in [blocks] order) with a not-done row;
/// c. else append a new row to [currentBlock] (falling back to the first
///    block if there's no current block) — the "logged more sets than
///    planned" case (§3.3).
///
/// Null only when [blocks] is empty (nothing to log against) — a defensive
/// case that shouldn't happen in practice, since a session always has at
/// least one exercise block.
///
/// Deliberately separate from [decideWatchSetLog]'s guard/dedup work so that
/// **both** the actual logging and the prefill published to the watch
/// ([watchSetPrefill]) resolve to the *same* row — F5b's D-F5b.2 depends on
/// that: a prefill computed against a different row than the one a tap would
/// log into would silently show the wrong starting values.
WatchSetLogTarget? selectWatchSetLogTarget(
  List<ExerciseBlock> blocks,
  ExerciseBlock? currentBlock,
) {
  if (currentBlock != null) {
    final ri = currentBlock.rows.indexWhere((r) => !r.isDone);
    if (ri != -1) {
      return WatchSetLogTarget(blockIndex: blocks.indexOf(currentBlock), rowIndex: ri);
    }
  }

  for (var bi = 0; bi < blocks.length; bi++) {
    final ri = blocks[bi].rows.indexWhere((r) => !r.isDone);
    if (ri != -1) {
      return WatchSetLogTarget(blockIndex: bi, rowIndex: ri);
    }
  }

  final fallback = currentBlock ?? (blocks.isNotEmpty ? blocks.first : null);
  if (fallback == null) return null;
  return WatchSetLogTarget(blockIndex: blocks.indexOf(fallback), needsNewRow: true);
}

/// The weight/reps a watch-side adjust stepper should start from
/// (docs/watch/48-watch-f5b-set-adjust-plan.md D-F5b.2) — always computed by
/// the phone, never guessed on the watch. Both fields are non-null: a
/// candidate that can't supply *both* values is skipped rather than
/// half-filled, matching §4.1's "reps and weight travel together" rule.
class WatchSetPrefill {
  const WatchSetPrefill({required this.weight, required this.reps});

  final double weight;
  final int reps;
}

/// Resolves the prefill for the row [selectWatchSetLogTarget] would log into,
/// in D-F5b.2's priority order:
///
/// 1. the target row's own values (a planned/pre-filled set);
/// 2. else the exercise's previous performance *for that position*
///    ([ExerciseBlock.previousSets]);
/// 3. else the block's last already-done row (same session);
/// 4. else null — the watch falls back to its own default and shows it as
///    new data rather than as "an adjustment".
///
/// Null is also returned when there's no target at all (empty [blocks]).
WatchSetPrefill? watchSetPrefill(List<ExerciseBlock> blocks, ExerciseBlock? currentBlock) {
  final target = selectWatchSetLogTarget(blocks, currentBlock);
  if (target == null) return null;
  final block = blocks[target.blockIndex];
  // For a to-be-appended row, the position is the end of the list.
  final rowIndex = target.rowIndex ?? block.rows.length;

  // 1. The target row itself.
  if (rowIndex < block.rows.length) {
    final row = block.rows[rowIndex];
    final weight = row.weight;
    final reps = row.reps;
    if (weight != null && reps != null) {
      return WatchSetPrefill(weight: weight, reps: reps);
    }
  }

  // 2. Previous performance at the same position.
  if (rowIndex < block.previousSets.length) {
    final hint = block.previousSets[rowIndex];
    return WatchSetPrefill(weight: hint.weight, reps: hint.reps);
  }

  // 3. The block's last done row that carries both values.
  for (var i = block.rows.length - 1; i >= 0; i--) {
    final row = block.rows[i];
    if (!row.isDone) continue;
    final weight = row.weight;
    final reps = row.reps;
    if (weight != null && reps != null) {
      return WatchSetPrefill(weight: weight, reps: reps);
    }
  }

  // 4. Nothing to go on.
  return null;
}

/// Implements docs/watch/43-watch-f5-set-logging-plan.md §5.2/3–4:
///
/// 1. Session/finished/saving guards → [WatchSetLogAction.reject].
/// 2. [eventId] seen before (in [recentEventIds]) → [WatchSetLogAction.dedupe].
/// 3. Otherwise, log into [selectWatchSetLogTarget]'s row.
/// 4. No block at all to log against (empty [blocks]) → [WatchSetLogAction.reject]
///    as a defensive fallback; this shouldn't happen in practice since a
///    session always has at least one exercise block.
WatchSetLogDecision decideWatchSetLog({
  required String eventSessionClientId,
  required String? currentSessionClientId,
  required bool sessionFinished,
  required bool saving,
  required String eventId,
  required List<String> recentEventIds,
  required List<ExerciseBlock> blocks,
  required ExerciseBlock? currentBlock,
}) {
  if (eventSessionClientId != currentSessionClientId) {
    return const WatchSetLogDecision(action: WatchSetLogAction.reject);
  }
  if (sessionFinished || saving) {
    return const WatchSetLogDecision(action: WatchSetLogAction.reject);
  }
  if (recentEventIds.contains(eventId)) {
    return const WatchSetLogDecision(action: WatchSetLogAction.dedupe);
  }

  final target = selectWatchSetLogTarget(blocks, currentBlock);
  if (target == null) {
    return const WatchSetLogDecision(action: WatchSetLogAction.reject);
  }
  return WatchSetLogDecision(action: WatchSetLogAction.log, target: target);
}
