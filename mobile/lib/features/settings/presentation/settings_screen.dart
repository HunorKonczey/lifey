import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/error_message.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/settings_controller.dart';
import '../domain/user_settings.dart';

/// Settings: unit system, theme, and optional daily calorie/macro goals.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: false),
      body: state.when(
        data: (settings) => _SettingsForm(initial: settings),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(settingsControllerProvider),
        ),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.initial});

  final UserSettings initial;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late UnitSystem _unitSystem;
  late ThemePreference _theme;
  late final TextEditingController _calorieController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _unitSystem = widget.initial.unitSystem;
    _theme = widget.initial.theme;
    _calorieController = TextEditingController(text: widget.initial.dailyCalorieGoal?.toString() ?? '');
    _proteinController = TextEditingController(text: widget.initial.dailyProteinGoal?.toString() ?? '');
    _carbsController = TextEditingController(text: widget.initial.dailyCarbsGoal?.toString() ?? '');
    _fatController = TextEditingController(text: widget.initial.dailyFatGoal?.toString() ?? '');
  }

  @override
  void dispose() {
    _calorieController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  int? _parseGoal(String text) => text.trim().isEmpty ? null : int.parse(text.trim());

  String? _goalValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 0) return 'Enter a non-negative whole number';
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await ref.read(settingsControllerProvider.notifier).save(
            UserSettings(
              unitSystem: _unitSystem,
              theme: _theme,
              dailyCalorieGoal: _parseGoal(_calorieController.text),
              dailyProteinGoal: _parseGoal(_proteinController.text),
              dailyCarbsGoal: _parseGoal(_carbsController.text),
              dailyFatGoal: _parseGoal(_fatController.text),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } catch (error) {
      setState(() => _submitError = friendlyError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Units', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<UnitSystem>(
            segments: const [
              ButtonSegment(value: UnitSystem.metric, label: Text('Metric (kg)')),
              ButtonSegment(value: UnitSystem.imperial, label: Text('Imperial (lb)')),
            ],
            selected: {_unitSystem},
            onSelectionChanged: (selection) => setState(() => _unitSystem = selection.first),
          ),
          const SizedBox(height: 24),
          Text('Theme', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemePreference>(
            segments: const [
              ButtonSegment(value: ThemePreference.light, label: Text('Light')),
              ButtonSegment(value: ThemePreference.dark, label: Text('Dark')),
              ButtonSegment(value: ThemePreference.system, label: Text('System')),
            ],
            selected: {_theme},
            onSelectionChanged: (selection) => setState(() => _theme = selection.first),
          ),
          const SizedBox(height: 24),
          Text('Daily goals', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Leave blank for no goal',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _calorieController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Calories',
              suffixText: 'kcal',
              border: OutlineInputBorder(),
            ),
            validator: _goalValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _proteinController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Protein',
              suffixText: 'g',
              border: OutlineInputBorder(),
            ),
            validator: _goalValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _carbsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Carbs',
              suffixText: 'g',
              border: OutlineInputBorder(),
            ),
            validator: _goalValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _fatController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Fat',
              suffixText: 'g',
              border: OutlineInputBorder(),
            ),
            validator: _goalValidator,
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            Text(_submitError!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
