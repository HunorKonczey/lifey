import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/search_normalize.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../application/exercise_controller.dart';
import '../application/workout_template_controller.dart';
import '../domain/exercise.dart';
import '../domain/exercise_enums.dart';
import '../domain/workout_template.dart';

// ---------------------------------------------------------------------------
// Entry model (mutable; lives only in screen state)
// ---------------------------------------------------------------------------

class _ExerciseEntry {
  _ExerciseEntry({required this.clientId, this.targetSets});
  final String clientId;
  int? targetSets;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class CreateTemplateScreen extends ConsumerStatefulWidget {
  const CreateTemplateScreen({super.key, this.template});

  final WorkoutTemplate? template;

  @override
  ConsumerState<CreateTemplateScreen> createState() => _CreateTemplateScreenState();
}

class _CreateTemplateScreenState extends ConsumerState<CreateTemplateScreen> {
  final _name = TextEditingController();
  late final List<_ExerciseEntry> _exercises;
  bool _saving = false;
  bool _pendingSave = false;
  String? _templateClientId;
  Timer? _debounce;

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    if (template != null) {
      _name.text = template.name;
      _exercises = template.exercises
          .map((te) => _ExerciseEntry(clientId: te.exerciseClientId, targetSets: te.targetSets))
          .toList();
    } else {
      _exercises = [];
    }
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (!_isEditing && _templateClientId == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _autoSave);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _autoSave() async {
    final name = _name.text.trim();
    if (name.isEmpty || _exercises.isEmpty) return;
    if (_saving) {
      _pendingSave = true;
      return;
    }
    _pendingSave = false;
    setState(() => _saving = true);
    try {
      await _persist();
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: AppLocalizations.of(context)!.couldNotSaveTemplateMessage,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        if (_pendingSave) Future.microtask(_autoSave);
      }
    }
  }

  Future<void> _persist() async {
    final notifier = ref.read(workoutTemplateControllerProvider.notifier);
    final name = _name.text.trim();
    final templateExercises = _exercises
        .map((e) => TemplateExercise(exerciseClientId: e.clientId, targetSets: e.targetSets))
        .toList();
    final id = _isEditing ? widget.template!.clientId : _templateClientId;
    if (id != null) {
      await notifier.updateTemplate(
        clientId: id,
        name: name,
        exercises: templateExercises,
      );
    } else {
      _templateClientId = await notifier.createTemplate(
        name: name,
        exercises: templateExercises,
      );
    }
  }

  Future<void> _editSets(int index) async {
    final l10n = AppLocalizations.of(context)!;
    // The controller is owned by _TargetSetsDialog and disposed by its State.dispose(),
    // which Flutter calls only after the exit animation finishes — avoiding the
    // "controller used after dispose" crash that happens when dispose() is called
    // manually right after showDialog returns (while the animation is still running).
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _TargetSetsDialog(
        initialValue: _exercises[index].targetSets?.toString() ?? '',
        cancelLabel: l10n.cancelButton,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _exercises[index] = _ExerciseEntry(
        clientId: _exercises[index].clientId,
        targetSets: result.isEmpty ? null : int.tryParse(result),
      );
    });
    _autoSave();
  }

  void _removeExercise(int index) {
    setState(() => _exercises.removeAt(index));
    _autoSave();
  }

  void _openExercisePicker(List<Exercise> allExercises) {
    final existing = _exercises.map((e) => e.clientId).toSet();
    final available = allExercises.where((e) => !existing.contains(e.clientId)).toList();

    if (available.isEmpty) {
      AppSnackbar.showInfo(
        context,
        title: AppLocalizations.of(context)!.everyExerciseAlreadyInSessionMessage,
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ExercisePickerSheet(
        exercises: available,
        onPick: (exercise) {
          Navigator.pop(ctx);
          setState(() => _exercises.add(_ExerciseEntry(clientId: exercise.clientId)));
          _autoSave();
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final statusTop = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final contentTop = statusTop + 8.0 + 58.0 + 12.0;

    final allExercises = ref.watch(exerciseControllerProvider).maybeWhen(
          data: (exercises) => exercises,
          orElse: () => const <Exercise>[],
        );
    final exercisesMap = {for (final e in allExercises) e.clientId: e};

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          // ── Content ──────────────────────────────────────────────────
          ReorderableListView(
            padding: EdgeInsets.fromLTRB(16, contentTop, 16, bottomPad + 24),
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                final item = _exercises.removeAt(oldIndex);
                _exercises.insert(newIndex, item);
              });
              _autoSave();
            },
            header: _buildHeader(context, l10n, scheme, allExercises),
            footer: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _buildDashedButton(context, l10n, scheme, allExercises),
            ),
            children: [
              for (var i = 0; i < _exercises.length; i++)
                _buildExerciseRow(context, i, exercisesMap, l10n, scheme),
            ],
          ),

          // ── Floating app bar ──────────────────────────────────────────
          Positioned(
            top: statusTop + 8,
            left: 12,
            right: 12,
            child: AdaptiveAppBar(
              title: _isEditing ? l10n.editTemplateTitle : l10n.newTemplateTitle,
              onBack: () => Navigator.of(context).pop(),
              trailing: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    List<Exercise> allExercises,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // NAME label
        Text(
          l10n.templateNameLabel.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        // Name input
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            filled: true,
            fillColor: scheme.surfaceContainerLow,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: scheme.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // EXERCISES header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.exercisesLabel.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: scheme.onSurfaceVariant,
              ),
            ),
            GestureDetector(
              onTap: () => _openExercisePicker(allExercises),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 18, color: scheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      l10n.addButton,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildExerciseRow(
    BuildContext context,
    int index,
    Map<String, Exercise> exercisesMap,
    AppLocalizations l10n,
    ColorScheme scheme,
  ) {
    final entry = _exercises[index];
    final ex = exercisesMap[entry.clientId];

    // Subtitle: "3 sets · Barbell"
    final parts = <String>[];
    if (entry.targetSets != null) parts.add(l10n.setsCountLabel(entry.targetSets!));
    if (ex?.equipment != null) parts.add(equipmentLabel(l10n, ex!.equipment!));
    final subtitle = parts.join(' · ');

    // Badge icon (same logic as exercises tab)
    final IconData badgeIcon;
    if (ex?.category == 'CARDIO') {
      badgeIcon = Icons.directions_run;
    } else if (ex?.equipment == 'BODYWEIGHT') {
      badgeIcon = Icons.sports_gymnastics;
    } else {
      badgeIcon = Icons.fitness_center;
    }

    return Padding(
      key: ValueKey(entry.clientId),
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Drag handle
            ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_indicator, size: 22, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 11),
            // Icon badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Icon(badgeIcon, size: 20, color: scheme.primary)),
            ),
            const SizedBox(width: 11),
            // Name + subtitle — tap to edit sets
            Expanded(
              child: GestureDetector(
                onTap: () => _editSets(index),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex?.name ?? entry.clientId,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Remove button
            GestureDetector(
              onTap: () => _removeExercise(index),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Icon(Icons.close, size: 19, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashedButton(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
    List<Exercise> allExercises,
  ) {
    return GestureDetector(
      onTap: () => _openExercisePicker(allExercises),
      child: CustomPaint(
        painter: _DashedBorderPainter(color: scheme.outlineVariant),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 21, color: scheme.onSurfaceVariant),
              const SizedBox(width: 7),
              Text(
                l10n.addExerciseTitle,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
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
// Dashed border painter
// ---------------------------------------------------------------------------

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 6.0).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += 10.0;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// Target sets dialog — owns the TextEditingController so Flutter disposes it
// after the exit animation, not mid-animation.
// ---------------------------------------------------------------------------

class _TargetSetsDialog extends StatefulWidget {
  const _TargetSetsDialog({required this.initialValue, required this.cancelLabel});

  final String initialValue;
  final String cancelLabel;

  @override
  State<_TargetSetsDialog> createState() => _TargetSetsDialogState();
}

class _TargetSetsDialogState extends State<_TargetSetsDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.targetSetsDialogTitle),
      content: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        autofocus: true,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(hintText: '3'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: Text(l10n.okButton),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise picker bottom sheet
// ---------------------------------------------------------------------------

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet({required this.exercises, required this.onPick});

  final List<Exercise> exercises;
  final void Function(Exercise) onPick;

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _query = '';

  List<Exercise> get _filtered => _query.isEmpty
      ? widget.exercises
      : widget.exercises
          .where((e) => normalizeForSearch(e.name).contains(normalizeForSearch(_query)))
          .toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad + 16),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: l10n.searchExercisesHint,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: scheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (q) => setState(() => _query = q),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final ex = _filtered[i];
                  return ListTile(
                    onTap: () => widget.onPick(ex),
                    title: Text(ex.name),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
