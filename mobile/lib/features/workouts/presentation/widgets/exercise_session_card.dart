import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/lifey_sheet.dart';
import '../../../../shared/widgets/ds/list_group.dart';
import '../../data/workout_session_repository.dart';
import '../../domain/personal_record.dart';

// ---------------------------------------------------------------------------
// Presentation-layer models — screen state only, never persisted directly.
// A SetRow is persisted as ExerciseSetInput only when doneAt != null.
// ---------------------------------------------------------------------------

class SetRow {
  SetRow({this.weight, this.reps, this.doneAt});

  double? weight;
  int? reps;

  /// Stamped when the user taps the trailing circle (marks set as done).
  /// Becomes ExerciseSetInput.performedAt on persist.
  DateTime? doneAt;

  /// Record types this row earned against the exercise's PR baseline,
  /// recomputed from scratch after every done-row change (see
  /// LogSessionScreen._recomputePrFlags) — screen state only, never
  /// persisted, same as [doneAt]'s presentation-only nature.
  Set<PrType> prTypes = const {};

  bool get isDone => doneAt != null;
}

class ExerciseBlock {
  ExerciseBlock({
    required this.exerciseClientId,
    required this.exerciseName,
    this.targetSets,
    required this.rows,
  });

  final String exerciseClientId;
  String
      exerciseName; // may be filled from catalog after construction (template case)

  /// How many sets this exercise plans for, when known. Mutable for the same
  /// reason [exerciseName] is: it can arrive after construction — a session
  /// rebuilt from a row whose `targetSets` a server round-trip dropped gets
  /// it back from the originating template (see
  /// [LogSessionScreen._loadTemplateTargetSets]).
  int? targetSets;
  final List<SetRow> rows;

  /// Muscle-group code (e.g. "CHEST"), filled from the catalog at the same
  /// time as [exerciseName] (see [LogSessionScreen.build]) — feeds the
  /// per-exercise badge icon on the workout-success dialog
  /// (workout_success_sheet.dart).
  String? exerciseCategory;

  /// Previous-performance hints for this exercise, sorted to line up
  /// positionally with [rows] (index 0 = row 0, etc). Filled asynchronously
  /// after construction — see [LogSessionScreen._loadPreviousPerformance].
  List<PreviousSetHint> previousSets = const [];

  /// This exercise's PR baseline (every set ever logged, excluding the
  /// current session) — null until loaded (see
  /// [LogSessionScreen._loadPrBaselines]). While null, PR detection stays
  /// silent rather than celebrating against a half-loaded history.
  PrBaseline? prBaseline;
}

// ---------------------------------------------------------------------------
// ExerciseSessionCard
// ---------------------------------------------------------------------------

/// Height of a set row and of the KG / REPS pills inside it (docs/redesign/
/// 77-mobile-redesign-plan.md R3.5: 52 dp rows).
const double kSetRowHeight = 52;

/// The done-check button of a set row.
const double kSetCheckSize = 40;

/// One exercise of the live strength screen: its name with "Best 50 kg × 8 ·
/// e1RM 63.3 kg", the set table (SET · PREV · KG · REPS) with 52 dp rows whose
/// KG and REPS are filled inputs and a 40 dp check button, and "+ Add set"
/// (canvas Lifey 3 › 3.2). A done row takes the improvement-green tint, its
/// PREV stays faint; ↑ is always the improvement colour and the trophy always
/// the record colour, here as in the list and the celebration.
class ExerciseSessionCard extends StatefulWidget {
  const ExerciseSessionCard({
    super.key,
    required this.block,
    required this.onRowMarkDone,
    required this.onRowReopen,
    required this.onRowEdit,
    required this.onRowDelete,
    required this.onRowDuplicate,
    required this.onAddSet,
    required this.onRemoveExercise,
  });

  final ExerciseBlock block;

  /// Check tap on a plan row that already has its weight and reps — screen
  /// sets doneAt = now and autosaves.
  final void Function(int index) onRowMarkDone;

  /// Check tap on a done row — screen clears doneAt and autosaves.
  final void Function(int index) onRowReopen;

  /// Compact editor submitted — screen updates weight/reps and stamps doneAt
  /// (a row is logged by giving it values).
  final void Function(int index, double? weight, int? reps) onRowEdit;

  /// "Remove set" in a row's long-press menu — screen removes the row.
  final void Function(int index) onRowDelete;

  /// Double-tap on a row / "Duplicate set" in its menu — screen fills the next
  /// row or appends a duplicate.
  final void Function(int index) onRowDuplicate;

  /// bool arg = whether to prefill the new row from previous performance
  /// (true when triggered by a double-tap on the "Add set" row).
  final void Function(bool prefillFromPrevious) onAddSet;
  final VoidCallback onRemoveExercise;

  @override
  State<ExerciseSessionCard> createState() => _ExerciseSessionCardState();
}

class _ExerciseSessionCardState extends State<ExerciseSessionCard> {
  Future<void> _handleDoubleTap(int index) async {
    widget.onRowDuplicate(index);
    // onRowDuplicate mutates block.rows in-place, so index+1 already exists.
    await _openEditor(index + 1, focusReps: false);
  }

  Future<void> _handleAddSet(bool focusReps, {bool prefillFromPrevious = false}) async {
    widget.onAddSet(prefillFromPrevious);
    // onAddSet appends a row in-place (optionally prefilled); open editor
    // for it immediately.
    await _openEditor(widget.block.rows.length - 1, focusReps: focusReps);
  }

  /// Double-tap on "Add set" — prefill the new row from the previous
  /// performance at this position, if there is one.
  Future<void> _handleAddSetDoubleTap() async {
    final hasPrevious = widget.block.rows.length < widget.block.previousSets.length;
    await _handleAddSet(false, prefillFromPrevious: hasPrevious);
  }

  Future<void> _openEditor(
    int index, {
    bool focusReps = false,
    double? presetWeight,
    int? presetReps,
  }) async {
    final row = widget.block.rows[index];
    final l10n = AppLocalizations.of(context)!;
    final result = await showLifeySheet<({double? weight, int? reps})>(
      context: context,
      useRootNavigator: true,
      title: l10n.editSetTitle,
      builder: (_) => _CompactSetEditor(
        initialWeight: presetWeight ?? row.weight,
        initialReps: presetReps ?? row.reps,
        focusReps: focusReps,
      ),
    );
    if (!mounted) return;
    if (result != null) {
      widget.onRowEdit(index, result.weight, result.reps);
    }
  }

  /// Tap on the "PREV" column — open the editor prefilled with the previous
  /// session's weight/reps for this row, so the user can save it as-is or
  /// tweak it before confirming.
  Future<void> _handleUsePrevious(int index, PreviousSetHint previous) {
    return _openEditor(index, presetWeight: previous.weight, presetReps: previous.reps);
  }

  /// The check: reopens a done row; logs a plan row — with its own values, or
  /// last time's when it has none — and asks for the values when there is
  /// nothing to log.
  void _handleCheckTap(int index) {
    final row = widget.block.rows[index];
    if (row.isDone) {
      widget.onRowReopen(index);
      return;
    }
    if (row.weight != null && row.reps != null) {
      widget.onRowMarkDone(index);
      return;
    }
    final previous = index < widget.block.previousSets.length ? widget.block.previousSets[index] : null;
    final weight = row.weight ?? previous?.weight;
    final reps = row.reps ?? previous?.reps;
    if (weight != null && reps != null) {
      widget.onRowEdit(index, weight, reps);
    } else {
      _openEditor(index);
    }
  }

  /// Long-press on a row: Duplicate set / Remove set — where the × of a plan
  /// row went.
  Future<void> _openRowMenu(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showLifeySheet<_RowAction>(
      context: context,
      useRootNavigator: true,
      title: '${widget.block.exerciseName} · ${l10n.setNumberLabel(index + 1)}',
      builder: (sheetContext) {
        void pick(_RowAction a) => Navigator.of(sheetContext).pop(a);
        return ListGroup(
          children: [
            ListRow(
              leading: ListIconHolder(
                  icon: Icons.content_copy_rounded, color: Theme.of(sheetContext).colorScheme.primary),
              title: l10n.duplicateMenuItem,
              onTap: () => pick(_RowAction.duplicate),
            ),
            ListRow(
              leading: ListIconHolder(icon: Icons.delete_rounded, color: sheetContext.metricColors.heart),
              title: l10n.removeButton,
              onTap: () => pick(_RowAction.remove),
            ),
          ],
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _RowAction.duplicate:
        await _handleDoubleTap(index);
      case _RowAction.remove:
        widget.onRowDelete(index);
    }
  }

  /// "Best 50 kg × 8 · e1RM 63.3 kg" from the exercise's PR baseline; null
  /// until the history has loaded or when there is no weighted set yet.
  String? _bestLine(AppLocalizations l10n) {
    final baseline = widget.block.prBaseline;
    final best = baseline?.maxWeight;
    if (baseline == null || best == null) return null;
    final f = NumberFormat('0.#', l10n.localeName);
    final reps = baseline.maxRepsByWeight[best];
    final oneRm = baseline.bestOneRm;
    final bestText = '${f.format(best)} ${l10n.statUnitKg}${reps == null ? '' : ' × $reps'}';
    if (oneRm == null) return l10n.exerciseBestLine(bestText);
    return l10n.exerciseBestLineWithOneRm(bestText, '${f.format(oneRm)} ${l10n.statUnitKg}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bestLine = _bestLine(l10n);

    return LifeyCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(name: widget.block.exerciseName, best: bestLine, onRemove: widget.onRemoveExercise),
          const SizedBox(height: AppSpacing.s16),
          const _ColumnHeader(),
          const SizedBox(height: AppSpacing.s4),
          for (int i = 0; i < widget.block.rows.length; i++)
            _SetRowTile(
              index: i,
              row: widget.block.rows[i],
              previous: i < widget.block.previousSets.length ? widget.block.previousSets[i] : null,
              onTap: (focusReps) => _openEditor(i, focusReps: focusReps),
              onTapPrevious: i < widget.block.previousSets.length
                  ? () => _handleUsePrevious(i, widget.block.previousSets[i])
                  : null,
              onDoubleTap: () => _handleDoubleTap(i),
              onLongPress: () => _openRowMenu(i),
              onCheckTap: () => _handleCheckTap(i),
            ),
          const SizedBox(height: AppSpacing.s4),
          _AddSetRow(onAddSet: _handleAddSet, onDoubleTap: _handleAddSetDoubleTap),
        ],
      ),
    );
  }
}

enum _RowAction { duplicate, remove }

// ---------------------------------------------------------------------------
// Card header: name + best + overflow menu
// ---------------------------------------------------------------------------

enum _CardMenu { remove }

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.name, required this.best, required this.onRemove});

  final String name;
  final String? best;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.titleLarge!.copyWith(height: 1.2, color: p.text)),
              if (best != null) ...[
                const SizedBox(height: 2),
                Text(best!, style: t.titleSmall!.copyWith(fontWeight: FontWeight.w500, height: 1.3, color: p.text2)),
              ],
            ],
          ),
        ),
        PopupMenuButton<_CardMenu>(
          icon: Icon(Icons.more_horiz_rounded, size: 24, color: p.text2),
          onSelected: (action) {
            if (action == _CardMenu.remove) onRemove();
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: _CardMenu.remove,
              child: Text(AppLocalizations.of(ctx)!.removeExerciseMenuItem),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Column header: SET / PREV / KG / REPS
// ---------------------------------------------------------------------------

/// Column widths of the set table: the header and every row share them.
const double _kSetColumnWidth = 34;
const double _kPreviousColumnWidth = 64;

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader();

  /// A column label that shrinks to its column instead of overflowing ("SZETT"
  /// at 130 % text).
  static Widget _fit(String text, TextStyle style, {Alignment alignment = Alignment.centerLeft}) =>
      FittedBox(fit: BoxFit.scaleDown, alignment: alignment, child: Text(text, maxLines: 1, style: style));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = AppType.sectionLabel(color: context.palette.text2);
    return Row(
      children: [
        SizedBox(width: _kSetColumnWidth, child: _fit(l10n.setColumnLabel, style)),
        SizedBox(
          width: _kPreviousColumnWidth,
          // Lined up with the values under it (8 dp in), and clear of the
          // SET label that fills its narrow column at large text.
          child: Padding(
            padding: const EdgeInsets.only(left: AppSpacing.s8, right: AppSpacing.s4),
            child: _fit(l10n.previousColumnLabel, style),
          ),
        ),
        Expanded(child: _fit(l10n.kgColumnLabel, style, alignment: Alignment.center)),
        const SizedBox(width: AppSpacing.s8),
        Expanded(child: _fit(l10n.repsColumnLabel, style, alignment: Alignment.center)),
        const SizedBox(width: AppSpacing.s8 + kSetCheckSize),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Individual set row
// ---------------------------------------------------------------------------

class _SetRowTile extends StatelessWidget {
  const _SetRowTile({
    required this.index,
    required this.row,
    required this.previous,
    required this.onTap,
    required this.onTapPrevious,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onCheckTap,
  });

  final int index;
  final SetRow row;
  final PreviousSetHint? previous;

  /// focusReps: false = weight field, true = reps field.
  final void Function(bool focusReps) onTap;

  /// Tap on the "PREV" column — null when there's no previous value to use.
  final VoidCallback? onTapPrevious;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final VoidCallback onCheckTap;

  static String _formatWeight(double w) => w == w.truncateToDouble() ? w.toInt().toString() : w.toString();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mc = context.metricColors;
    final l10n = AppLocalizations.of(context)!;
    final isDone = row.isDone;
    final improvement = mc.improvement;

    // An undone row shows what it holds — or, faintly, what last time did here.
    final weightText = row.weight != null ? _formatWeight(row.weight!) : (previous != null ? _formatWeight(previous!.weight) : '—');
    final repsText = row.reps != null ? row.reps.toString() : (previous != null ? previous!.reps.toString() : '—');
    final weightIsHint = row.weight == null && previous != null;
    final repsIsHint = row.reps == null && previous != null;

    final weightArrow = isDone ? _arrow(context, row.weight, previous?.weight) : null;
    final repsArrow = isDone ? _arrow(context, row.reps, previous?.reps, showStagnant: true) : null;

    final showTrophy = isDone && row.prTypes.isNotEmpty;
    final Widget? repsTrailing = (repsArrow == null && !showTrophy)
        ? null
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (repsArrow != null) repsArrow,
            if (showTrophy) ...[
              if (repsArrow != null) const SizedBox(width: 3),
              const _PrTrophy(),
            ],
          ]);

    final previousText = previous != null ? '${_formatWeight(previous!.weight)}×${previous!.reps}' : '—';

    return GestureDetector(
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 250)),
        curve: Curves.easeOut,
        constraints: const BoxConstraints(minHeight: kSetRowHeight),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: isDone ? improvement.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Row(
          children: [
            SizedBox(
              width: _kSetColumnWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s12),
                child: Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: isDone ? improvement : p.text2, fontFeatures: AppType.tabular),
                ),
              ),
            ),
            // Separate tap target so tapping "PREV" fills this row from the
            // previous session instead of competing with the pills.
            GestureDetector(
              onTap: onTapPrevious,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: _kPreviousColumnWidth,
                height: kSetRowHeight,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.s8, right: AppSpacing.s4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          previousText,
                          style: Theme.of(context).textTheme.titleSmall!.copyWith(
                            fontWeight: FontWeight.w600,
                            // Faint, and it stays faint on a done row.
                            color: p.text3,
                            fontFeatures: AppType.tabular,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _ValuePill(
                text: weightText,
                hint: weightIsHint,
                done: isDone,
                trailing: weightArrow,
                semanticsLabel: '${l10n.kgColumnLabel} $weightText',
                onTap: () => onTap(false),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: _ValuePill(
                text: repsText,
                hint: repsIsHint,
                done: isDone,
                trailing: repsTrailing,
                semanticsLabel: '${l10n.repsColumnLabel} $repsText',
                onTap: () => onTap(true),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            _CheckButton(done: isDone, onTap: onCheckTap),
            const SizedBox(width: AppSpacing.s4),
          ],
        ),
      ),
    );
  }

  /// ↑ in the improvement colour when [current] beat [previous], ↓ in the
  /// negative colour when it fell short; a dash for unchanged reps
  /// ([showStagnant]). Nothing without a previous value to compare with.
  static Widget? _arrow(BuildContext context, num? current, num? previous, {bool showStagnant = false}) {
    if (current == null || previous == null) return null;
    final mc = context.metricColors;
    if (current == previous) {
      if (!showStagnant) return null;
      return Icon(Icons.remove_rounded, size: 16, color: context.palette.text3);
    }
    final up = current > previous;
    return Icon(
      up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
      size: 16,
      color: up ? mc.improvement : mc.negative,
    );
  }
}

/// The trophy of a set that set a record: a quick scale-in in the record
/// colour, without the motion under reduced motion.
class _PrTrophy extends StatelessWidget {
  const _PrTrophy();

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.emoji_events_rounded, size: 18, color: context.metricColors.record);
    if (MediaQuery.of(context).disableAnimations) return icon;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: icon,
    );
  }
}

/// A KG / REPS input pill: a filled 44 dp field on a plan row, bare bright
/// text on a done row. Tapping opens the editor.
class _ValuePill extends StatelessWidget {
  const _ValuePill({
    required this.text,
    required this.hint,
    required this.done,
    required this.onTap,
    required this.semanticsLabel,
    this.trailing,
  });

  final String text;

  /// The value is last time's, shown faintly until the row is logged.
  final bool hint;
  final bool done;
  final Widget? trailing;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = BorderRadius.circular(AppRadius.control);
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: done ? Colors.transparent : p.control,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: 44,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      text,
                      style: AppType.number(20, weight: FontWeight.w800, color: done ? p.text : (hint ? p.text3 : p.text2)),
                    ),
                    if (trailing != null) ...[const SizedBox(width: 4), trailing!],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 40 dp check of a set row: outlined while the set is still to do, filled
/// in the improvement colour once it is logged.
class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.done, required this.onTap});

  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mc = context.metricColors;
    final radius = BorderRadius.circular(AppRadius.control);
    return Semantics(
      button: true,
      checked: done,
      label: AppLocalizations.of(context)!.setDoneLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: kSetCheckSize,
        height: kSetRowHeight,
        child: Center(
          child: Material(
            color: done ? mc.improvement : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: done ? BorderSide.none : BorderSide(color: context.elevation.border),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: SizedBox.square(
                dimension: kSetCheckSize,
                child: Icon(Icons.check_rounded, size: 22, color: done ? p.card : p.text2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add set row
// ---------------------------------------------------------------------------

class _AddSetRow extends StatelessWidget {
  const _AddSetRow({required this.onAddSet, required this.onDoubleTap});

  final void Function(bool focusReps) onAddSet;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primary = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        onTapUp: (d) => onAddSet(d.localPosition.dx >= constraints.maxWidth / 2),
        onDoubleTap: onDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 22, color: primary),
              const SizedBox(width: AppSpacing.s8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    l10n.addSetTitle,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact kg + reps editor (in a sheet — no exercise picker)
// ---------------------------------------------------------------------------

class _CompactSetEditor extends StatefulWidget {
  const _CompactSetEditor({this.initialWeight, this.initialReps, this.focusReps = false});

  final double? initialWeight;
  final int? initialReps;
  final bool focusReps;

  @override
  State<_CompactSetEditor> createState() => _CompactSetEditorState();
}

class _CompactSetEditorState extends State<_CompactSetEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weight;
  late final TextEditingController _reps;

  @override
  void initState() {
    super.initState();
    final w = widget.initialWeight;
    _weight = TextEditingController(
      text: w == null ? '' : (w == w.truncateToDouble() ? w.toInt().toString() : w.toString()),
    );
    _reps = TextEditingController(text: widget.initialReps?.toString() ?? '');
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final weight = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    final reps = int.tryParse(_reps.text.trim());
    Navigator.of(context).pop<({double? weight, int? reps})>((weight: weight, reps: reps));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _weight,
                  autofocus: !widget.focusReps,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.kgColumnLabel),
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l10n.enterANumberError;
                    }
                    final n = double.tryParse(v.trim().replaceAll(',', '.'));
                    if (n == null) return l10n.enterANumberError;
                    if (n < 0) return l10n.mustBeZeroOrMoreError;
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: TextFormField(
                  controller: _reps,
                  autofocus: widget.focusReps,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(labelText: l10n.repsLabel),
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l10n.enterANumberError;
                    }
                    final n = int.tryParse(v.trim());
                    if (n == null) return l10n.enterANumberError;
                    if (n <= 0) return l10n.mustBeGreaterThanZeroShortError;
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: Text(l10n.saveButton),
          ),
        ],
      ),
    );
  }
}
