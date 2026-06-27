import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

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
  String exerciseName; // may be filled from catalog after construction (template case)
  final int? targetSets;
  final List<SetRow> rows;
}

// ---------------------------------------------------------------------------
// ExerciseSessionCard
// ---------------------------------------------------------------------------

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

  /// Circle tap on a plan row — screen sets doneAt = now and autosaves.
  final void Function(int index) onRowMarkDone;

  /// Check tap on a done row — screen clears doneAt and autosaves.
  final void Function(int index) onRowReopen;

  /// Compact editor submitted — screen updates weight/reps and autosaves.
  final void Function(int index, double? weight, int? reps) onRowEdit;

  /// Close icon tap while a row is in edit mode — screen removes row.
  final void Function(int index) onRowDelete;

  /// Double-tap on a row — screen fills next row or appends duplicate.
  final void Function(int index) onRowDuplicate;

  final VoidCallback onAddSet;
  final VoidCallback onRemoveExercise;

  @override
  State<ExerciseSessionCard> createState() => _ExerciseSessionCardState();
}

class _ExerciseSessionCardState extends State<ExerciseSessionCard> {
  /// The row currently shown in "edit mode" (close icon visible).
  int? _editingIndex;

  Future<void> _handleDoubleTap(int index) async {
    widget.onRowDuplicate(index);
    // onRowDuplicate mutates block.rows in-place, so index+1 already exists.
    await _openEditor(index + 1, focusReps: false);
  }

  Future<void> _handleAddSet(bool focusReps) async {
    widget.onAddSet();
    // onAddSet appends a blank row in-place; open editor for it immediately.
    await _openEditor(widget.block.rows.length - 1, focusReps: focusReps);
  }

  Future<void> _openEditor(int index, {bool focusReps = false}) async {
    setState(() => _editingIndex = index);
    final row = widget.block.rows[index];
    final result = await showModalBottomSheet<({double? weight, int? reps})>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CompactSetEditor(
        initialWeight: row.weight,
        initialReps: row.reps,
        focusReps: focusReps,
      ),
    );
    if (!mounted) return;
    setState(() => _editingIndex = null);
    if (result != null) {
      widget.onRowEdit(index, result.weight, result.reps);
    }
  }

  void _handleTrailingTap(int index) {
    if (widget.block.rows[index].isDone) {
      // Checkmark → reopen (clear doneAt)
      widget.onRowReopen(index);
    } else {
      // Close icon → delete the plan row
      widget.onRowDelete(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHeader(
            name: widget.block.exerciseName,
            onRemove: widget.onRemoveExercise,
            scheme: scheme,
          ),
          const SizedBox(height: 13),
          _ColumnHeader(scheme: scheme),
          const SizedBox(height: 8),
          for (int i = 0; i < widget.block.rows.length; i++) ...[
            _SetRowTile(
              index: i,
              row: widget.block.rows[i],
              onTap: (focusReps) => _openEditor(i, focusReps: focusReps),
              onDoubleTap: () => _handleDoubleTap(i),
              onTrailingTap: () => _handleTrailingTap(i),
              scheme: scheme,
            ),
            const SizedBox(height: 5),
          ],
          const SizedBox(height: 5),
          _AddSetRow(onAddSet: _handleAddSet, scheme: scheme),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card header: icon + name + overflow menu
// ---------------------------------------------------------------------------

enum _CardMenu { remove }

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.name,
    required this.onRemove,
    required this.scheme,
  });

  final String name;
  final VoidCallback onRemove;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.fitness_center, size: 22, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
        ),
        PopupMenuButton<_CardMenu>(
          icon: Icon(
            Icons.more_horiz,
            size: 22,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
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
// Column header: SET / KG / REPS
// ---------------------------------------------------------------------------

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          letterSpacing: 0.5,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SizedBox(width: 34, child: Text(l10n.setColumnLabel, style: style)),
          Expanded(child: Text(l10n.kgColumnLabel, style: style)),
          Expanded(child: Text(l10n.repsColumnLabel, style: style)),
          const SizedBox(width: 34),
        ],
      ),
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
    required this.onTap,
    required this.onDoubleTap,
    required this.onTrailingTap,
    required this.scheme,
  });

  final int index;
  final SetRow row;
  // focusReps: false = weight field, true = reps field
  final void Function(bool focusReps) onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onTrailingTap;
  final ColorScheme scheme;

  String _formatWeight(double w) {
    if (w == w.truncateToDouble()) return w.toInt().toString();
    return w.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDone = row.isDone;
    final dimmed = scheme.onSurfaceVariant.withValues(alpha: 0.6);
    final setNumColor = isDone ? scheme.primary : dimmed;
    final valueColor = isDone ? scheme.onSurface : dimmed;
    final weightText = row.weight != null ? _formatWeight(row.weight!) : '—';
    final repsText = row.reps != null ? row.reps.toString() : '—';

    // Done row: check_circle (reopen on tap). Plan row: close (delete on tap).
    final trailingIcon = isDone ? Icons.check_circle : Icons.close;
    final trailingColor = isDone ? scheme.primary : dimmed;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: (d) => onTap(d.localPosition.dx >= constraints.maxWidth / 2),
          onDoubleTap: onDoubleTap,
          child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        decoration: BoxDecoration(
          color: isDone ? scheme.primary.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: setNumColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              child: Text(
                weightText,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              child: Text(
                repsText,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            // Separate tap target so trailing icon doesn't compete with row
            GestureDetector(
              onTap: onTrailingTap,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 34,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Icon(trailingIcon, size: 22, color: trailingColor),
                ),
              ),
            ),
          ],
        ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Add set row
// ---------------------------------------------------------------------------

class _AddSetRow extends StatelessWidget {
  const _AddSetRow({required this.onAddSet, required this.scheme});

  final void Function(bool focusReps) onAddSet;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        onTapUp: (d) => onAddSet(d.localPosition.dx >= constraints.maxWidth / 2),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 20, color: scheme.primary),
              const SizedBox(width: 7),
              Text(
                l10n.addSetTitle,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
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
// Compact kg + reps editor (bottom sheet — no exercise picker)
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
      text: w == null
          ? ''
          : (w == w.truncateToDouble() ? w.toInt().toString() : w.toString()),
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
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.editSetTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weight,
                    autofocus: !widget.focusReps,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.kgColumnLabel,
                      border: const OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = double.tryParse(v.trim().replaceAll(',', '.'));
                      if (n == null) return l10n.enterANumberError;
                      if (n < 0) return l10n.mustBeZeroOrMoreError;
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _reps,
                    autofocus: widget.focusReps,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: l10n.repsLabel,
                      border: const OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = int.tryParse(v.trim());
                      if (n == null) return l10n.enterANumberError;
                      if (n <= 0) return l10n.mustBeGreaterThanZeroShortError;
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: Text(l10n.saveButton)),
          ],
        ),
      ),
    );
  }
}
