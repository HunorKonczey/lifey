import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/exercise_controller.dart';
import '../../domain/exercise.dart';
import '../../domain/exercise_enums.dart';

/// Bottom sheet for creating or editing an exercise.
///
/// Pass [exercise] to open in edit mode; omit (or pass null) for add mode.
class AddExerciseSheet extends ConsumerStatefulWidget {
  const AddExerciseSheet({super.key, this.exercise});

  final Exercise? exercise;

  @override
  ConsumerState<AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends ConsumerState<AddExerciseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  String? _category;
  String? _equipment;
  int? _defaultRestSeconds;
  bool _submitting = false;
  String? _error;
  Timer? _autoSaveDebounce;

  bool get _isEdit => widget.exercise != null;

  static const List<int> _restDurationPresets = [30, 45, 60, 90, 120, 150, 180, 240, 300];

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.exercise?.name ?? '');
    _description = TextEditingController(text: widget.exercise?.description ?? '');
    _category = widget.exercise?.category;
    _equipment = widget.exercise?.equipment;
    _defaultRestSeconds = widget.exercise?.defaultRestSeconds;
    if (_isEdit) {
      _name.addListener(_scheduleAutoSave);
      _description.addListener(_scheduleAutoSave);
    }
  }

  void _scheduleAutoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 500), _autoSaveInBackground);
  }

  Future<void> _autoSaveInBackground() async {
    if (_submitting) return;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    try {
      await ref.read(exerciseControllerProvider.notifier).updateExercise(
        widget.exercise!.clientId,
        name: name,
        category: _category,
        equipment: _equipment,
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        defaultRestSeconds: _defaultRestSeconds,
      );
    } catch (_) {
      // Silent fail — the explicit save button surfaces errors.
    }
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final notifier = ref.read(exerciseControllerProvider.notifier);
      final description = _description.text.trim().isEmpty ? null : _description.text.trim();
      if (_isEdit) {
        await notifier.updateExercise(
          widget.exercise!.clientId,
          name: _name.text.trim(),
          category: _category,
          equipment: _equipment,
          description: description,
          defaultRestSeconds: _defaultRestSeconds,
        );
      } else {
        await notifier.addExercise(
          _name.text.trim(),
          category: _category,
          equipment: _equipment,
          description: description,
          defaultRestSeconds: _defaultRestSeconds,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _error = AppLocalizations.of(context)!.couldNotSaveExerciseMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // Scrollable (isScrollControlled + ListView, not a plain Column) since
  // "Use default" + 9 presets don't fit a fixed-height sheet on shorter
  // screens.
  Future<void> _pickRestDuration() async {
    final result = await showModalBottomSheet<({int? seconds})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final l10n = AppLocalizations.of(sheetCtx)!;
        final scheme = Theme.of(sheetCtx).colorScheme;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(l10n.useDefaultOptionLabel),
                trailing: _defaultRestSeconds == null
                    ? Icon(Icons.check, color: scheme.primary)
                    : null,
                onTap: () => Navigator.of(sheetCtx).pop((seconds: null)),
              ),
              for (final seconds in _restDurationPresets)
                ListTile(
                  title: Text(_formatDuration(seconds)),
                  trailing: _defaultRestSeconds == seconds
                      ? Icon(Icons.check, color: scheme.primary)
                      : null,
                  onTap: () => Navigator.of(sheetCtx).pop((seconds: seconds)),
                ),
            ],
          ),
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() => _defaultRestSeconds = result.seconds);
    if (_isEdit) _autoSaveInBackground();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? l10n.editExerciseTitle : l10n.addExerciseTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.nameLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.requiredFieldError : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            _ChipSection(
              label: l10n.categoryLabel,
              codes: kMuscleGroups,
              selected: _category,
              labelBuilder: (code) => muscleGroupLabel(l10n, code),
              onSelected: (code) {
                setState(() => _category = _category == code ? null : code);
                if (_isEdit) _autoSaveInBackground();
              },
            ),
            const SizedBox(height: 12),
            _ChipSection(
              label: l10n.equipmentLabel,
              codes: kEquipments,
              selected: _equipment,
              labelBuilder: (code) => equipmentLabel(l10n, code),
              onSelected: (code) {
                setState(() => _equipment = _equipment == code ? null : code);
                if (_isEdit) _autoSaveInBackground();
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.exerciseDescriptionLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickRestDuration,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.exerciseRestTimerFieldLabel,
                  border: const OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _defaultRestSeconds != null
                          ? _formatDuration(_defaultRestSeconds!)
                          : l10n.useDefaultOptionLabel,
                    ),
                    Icon(Icons.expand_more, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? l10n.saveChangesButton : l10n.saveButton),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip section
// ---------------------------------------------------------------------------

class _ChipSection extends StatelessWidget {
  const _ChipSection({
    required this.label,
    required this.codes,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  final String label;
  final List<String> codes;
  final String? selected;
  final String Function(String code) labelBuilder;
  final void Function(String code) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: codes.map((code) {
              final isSelected = selected == code;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(labelBuilder(code)),
                  selected: isSelected,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  showCheckmark: false,
                  onSelected: (_) => onSelected(code),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
