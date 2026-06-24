import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../application/exercise_controller.dart';
import '../application/workout_template_controller.dart';
import '../domain/workout_template.dart';

/// Full-screen form for creating a workout template, or editing one when
/// [template] is given: a name + chosen exercises.
class CreateTemplateScreen extends ConsumerStatefulWidget {
  const CreateTemplateScreen({super.key, this.template});

  final WorkoutTemplate? template;

  @override
  ConsumerState<CreateTemplateScreen> createState() =>
      _CreateTemplateScreenState();
}

class _CreateTemplateScreenState extends ConsumerState<CreateTemplateScreen> {
  final _name = TextEditingController();
  final Set<String> _selected = {};
  bool _saving = false;

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    if (template != null) {
      _name.text = template.name;
      _selected.addAll(template.exerciseClientIds);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return; // guard against a fast double-tap creating two templates
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (_name.text.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.enterANameMessage)));
      return;
    }
    if (_selected.isEmpty) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.pickAtLeastOneExerciseMessage)));
      return;
    }
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    try {
      final notifier = ref.read(workoutTemplateControllerProvider.notifier);
      if (_isEditing) {
        await notifier.updateTemplate(
          clientId: widget.template!.clientId,
          name: _name.text.trim(),
          exerciseClientIds: _selected.toList(),
        );
      } else {
        await notifier.createTemplate(
          name: _name.text.trim(),
          exerciseClientIds: _selected.toList(),
        );
      }
      navigator.pop();
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.couldNotSaveTemplateMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercisesState = ref.watch(exerciseControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(_isEditing ? l10n.editTemplateTitle : l10n.newTemplateTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.saveButton),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.templateNameLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: exercisesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('${l10n.couldNotLoadExercisesPrefix} $e')),
              data: (exercises) {
                if (exercises.isEmpty) {
                  return Center(child: Text(l10n.noExercisesAvailableMessage));
                }
                return ListView(
                  children: exercises.map((ex) {
                    return CheckboxListTile(
                      title: Text(ex.name),
                      value: _selected.contains(ex.clientId),
                      onChanged: (checked) => setState(() {
                        if (checked ?? false) {
                          _selected.add(ex.clientId);
                        } else {
                          _selected.remove(ex.clientId);
                        }
                      }),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
