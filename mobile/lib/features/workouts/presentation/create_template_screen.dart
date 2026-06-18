import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final Set<int> _selected = {};
  bool _saving = false;

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    if (template != null) {
      _name.text = template.name;
      _selected.addAll(template.exerciseIds);
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
    if (_name.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter a name')));
      return;
    }
    if (_selected.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Pick at least one exercise')));
      return;
    }
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    try {
      final notifier = ref.read(workoutTemplateControllerProvider.notifier);
      if (_isEditing) {
        await notifier.updateTemplate(
          id: widget.template!.id,
          name: _name.text.trim(),
          exerciseIds: _selected.toList(),
        );
      } else {
        await notifier.createTemplate(
          name: _name.text.trim(),
          exerciseIds: _selected.toList(),
        );
      }
      navigator.pop();
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save the template. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercisesState = ref.watch(exerciseControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit template' : 'New template'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
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
              decoration: const InputDecoration(
                labelText: 'Template name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: exercisesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Couldn't load exercises: $e")),
              data: (exercises) {
                if (exercises.isEmpty) {
                  return const Center(child: Text('No exercises available.'));
                }
                return ListView(
                  children: exercises.map((ex) {
                    return CheckboxListTile(
                      title: Text(ex.name),
                      value: _selected.contains(ex.id),
                      onChanged: (checked) => setState(() {
                        if (checked ?? false) {
                          _selected.add(ex.id);
                        } else {
                          _selected.remove(ex.id);
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
