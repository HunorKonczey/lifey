import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/error_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/error_view.dart';
import '../../water/presentation/water_sources_screen.dart';
import '../application/settings_controller.dart';
import '../domain/user_settings.dart';

/// Settings: unit system, theme, and optional daily calorie/macro goals.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.settingsTitle), centerTitle: false),
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
  late LanguagePreference _language;
  late final TextEditingController _calorieController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  late final TextEditingController _waterController;
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _unitSystem = widget.initial.unitSystem;
    _theme = widget.initial.theme;
    _language = widget.initial.language;
    _calorieController = TextEditingController(text: widget.initial.dailyCalorieGoal?.toString() ?? '');
    _proteinController = TextEditingController(text: widget.initial.dailyProteinGoal?.toString() ?? '');
    _carbsController = TextEditingController(text: widget.initial.dailyCarbsGoal?.toString() ?? '');
    _fatController = TextEditingController(text: widget.initial.dailyFatGoal?.toString() ?? '');
    _waterController =
        TextEditingController(text: widget.initial.dailyWaterGoalLiters?.toString() ?? '');
  }

  @override
  void dispose() {
    _calorieController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _waterController.dispose();
    super.dispose();
  }

  int? _parseGoal(String text) => text.trim().isEmpty ? null : int.parse(text.trim());

  double? _parseWaterGoal(String text) =>
      text.trim().isEmpty ? null : double.parse(text.replaceAll(',', '.').trim());

  String? _goalValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 0) return AppLocalizations.of(context)!.enterNonNegativeWholeNumber;
    return null;
  }

  String? _waterGoalValidator(String? value) {
    final text = value?.replaceAll(',', '.').trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null || parsed < 0) return AppLocalizations.of(context)!.enterNonNegativeNumber;
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
              language: _language,
              dailyCalorieGoal: _parseGoal(_calorieController.text),
              dailyProteinGoal: _parseGoal(_proteinController.text),
              dailyCarbsGoal: _parseGoal(_carbsController.text),
              dailyFatGoal: _parseGoal(_fatController.text),
              dailyWaterGoalLiters: _parseWaterGoal(_waterController.text),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.settingsSavedMessage)));
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
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.unitsLabel, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<UnitSystem>(
            segments: [
              ButtonSegment(value: UnitSystem.metric, label: Text(l10n.unitsMetric)),
              ButtonSegment(value: UnitSystem.imperial, label: Text(l10n.unitsImperial)),
            ],
            selected: {_unitSystem},
            onSelectionChanged: (selection) => setState(() => _unitSystem = selection.first),
          ),
          const SizedBox(height: 24),
          Text(l10n.themeLabel, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemePreference>(
            segments: [
              ButtonSegment(value: ThemePreference.light, label: Text(l10n.themeLight)),
              ButtonSegment(value: ThemePreference.dark, label: Text(l10n.themeDark)),
              ButtonSegment(value: ThemePreference.system, label: Text(l10n.optionSystem)),
            ],
            selected: {_theme},
            onSelectionChanged: (selection) => setState(() => _theme = selection.first),
          ),
          const SizedBox(height: 24),
          Text(l10n.languageLabel, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<LanguagePreference>(
            segments: [
              ButtonSegment(value: LanguagePreference.system, label: Text(l10n.optionSystem)),
              ButtonSegment(value: LanguagePreference.english, label: Text(l10n.languageEnglish)),
              ButtonSegment(value: LanguagePreference.hungarian, label: Text(l10n.languageHungarian)),
            ],
            selected: {_language},
            onSelectionChanged: (selection) => setState(() => _language = selection.first),
          ),
          const SizedBox(height: 24),
          Text(l10n.dailyGoalsLabel, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            l10n.leaveBlankForNoGoal,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _calorieController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.caloriesLabel,
              suffixText: 'kcal',
              border: const OutlineInputBorder(),
            ),
            validator: _goalValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _proteinController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.proteinLabel,
              suffixText: 'g',
              border: const OutlineInputBorder(),
            ),
            validator: _goalValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _carbsController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.carbsLabel,
              suffixText: 'g',
              border: const OutlineInputBorder(),
            ),
            validator: _goalValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _fatController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.fatLabel,
              suffixText: 'g',
              border: const OutlineInputBorder(),
            ),
            validator: _goalValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _waterController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.waterLabel,
              suffixText: 'L',
              border: const OutlineInputBorder(),
            ),
            validator: _waterGoalValidator,
          ),
          const SizedBox(height: 24),
          Text(l10n.waterSourcesLabel, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            l10n.waterSourcesDescription,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WaterSourcesScreen()),
            ),
            icon: const Icon(Icons.water_drop_outlined),
            label: Text(l10n.manageWaterSourcesButton),
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
                : Text(l10n.saveButton),
          ),
        ],
      ),
    );
  }
}
