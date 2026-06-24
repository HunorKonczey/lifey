import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/health/health_controller.dart';
import '../../../core/network/error_message.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/error_view.dart';
import '../../water/presentation/water_sources_screen.dart';
import '../application/settings_controller.dart';
import '../domain/user_settings.dart';

/// Settings: unit system, theme, language, and optional daily goals.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
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

// ---------------------------------------------------------------------------
// Form
// ---------------------------------------------------------------------------

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
    _calorieController =
        TextEditingController(text: widget.initial.dailyCalorieGoal?.toString() ?? '');
    _proteinController =
        TextEditingController(text: widget.initial.dailyProteinGoal?.toString() ?? '');
    _carbsController =
        TextEditingController(text: widget.initial.dailyCarbsGoal?.toString() ?? '');
    _fatController =
        TextEditingController(text: widget.initial.dailyFatGoal?.toString() ?? '');
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

  int? _parseGoal(String text) =>
      text.trim().isEmpty ? null : int.parse(text.trim());

  double? _parseWaterGoal(String text) =>
      text.trim().isEmpty ? null : double.parse(text.replaceAll(',', '.').trim());

  String? _goalValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 0) {
      return AppLocalizations.of(context)!.enterNonNegativeWholeNumber;
    }
    return null;
  }

  String? _waterGoalValidator(String? value) {
    final text = value?.replaceAll(',', '.').trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = double.tryParse(text);
    if (parsed == null || parsed < 0) {
      return AppLocalizations.of(context)!.enterNonNegativeNumber;
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.settingsSavedMessage)),
        );
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
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad + 24),
        children: [
          // ── Units ────────────────────────────────────────────────────────
          _SectionHeader(l10n.unitsLabel),
          _SettingsCard(
            child: SegmentedButton<UnitSystem>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: UnitSystem.metric, label: Text(l10n.unitsMetric)),
                ButtonSegment(value: UnitSystem.imperial, label: Text(l10n.unitsImperial)),
              ],
              selected: {_unitSystem},
              onSelectionChanged: (s) => setState(() => _unitSystem = s.first),
            ),
          ),
          const SizedBox(height: 20),

          // ── Appearance ──────────────────────────────────────────────────
          _SectionHeader(l10n.themeLabel),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<ThemePreference>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: ThemePreference.light, label: Text(l10n.themeLight)),
                    ButtonSegment(value: ThemePreference.dark, label: Text(l10n.themeDark)),
                    ButtonSegment(value: ThemePreference.system, label: Text(l10n.optionSystem)),
                  ],
                  selected: {_theme},
                  onSelectionChanged: (s) => setState(() => _theme = s.first),
                ),
                const SizedBox(height: 12),
                const _SettingsDivider(),
                const SizedBox(height: 12),
                Text(l10n.languageLabel,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                SegmentedButton<LanguagePreference>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                        value: LanguagePreference.system,
                        label: Text(l10n.optionSystem)),
                    ButtonSegment(
                        value: LanguagePreference.english,
                        label: Text(l10n.languageEnglish)),
                    ButtonSegment(
                        value: LanguagePreference.hungarian,
                        label: Text(l10n.languageHungarian)),
                  ],
                  selected: {_language},
                  onSelectionChanged: (s) => setState(() => _language = s.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Daily goals ──────────────────────────────────────────────────
          _SectionHeader(l10n.dailyGoalsLabel),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.leaveBlankForNoGoal,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                _GoalField(
                  controller: _calorieController,
                  label: l10n.caloriesLabel,
                  suffix: 'kcal',
                  validator: _goalValidator,
                ),
                _GoalField(
                  controller: _proteinController,
                  label: l10n.proteinLabel,
                  suffix: 'g',
                  validator: _goalValidator,
                ),
                _GoalField(
                  controller: _carbsController,
                  label: l10n.carbsLabel,
                  suffix: 'g',
                  validator: _goalValidator,
                ),
                _GoalField(
                  controller: _fatController,
                  label: l10n.fatLabel,
                  suffix: 'g',
                  validator: _goalValidator,
                ),
                _GoalField(
                  controller: _waterController,
                  label: l10n.waterLabel,
                  suffix: 'L',
                  decimal: true,
                  validator: _waterGoalValidator,
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Water sources ────────────────────────────────────────────────
          _SectionHeader(l10n.waterSourcesLabel),
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.waterSourcesDescription,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                const _SettingsDivider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.water_drop,
                        size: 18, color: scheme.onPrimaryContainer),
                  ),
                  title: Text(l10n.manageWaterSourcesButton),
                  trailing: Icon(Icons.chevron_right,
                      size: 18, color: scheme.onSurfaceVariant),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WaterSourcesScreen()),
                  ),
                ),
              ],
            ),
          ),

          // ── Apple Health (iOS only) ───────────────────────────────────────
          if (Platform.isIOS) ...[
            const SizedBox(height: 20),
            _SectionHeader(l10n.appleHealthLabel),
            const _SettingsCard(child: _AppleHealthToggle()),
          ],

          // ── Error / Save ─────────────────────────────────────────────────
          if (_submitError != null) ...[
            const SizedBox(height: 16),
            Text(
              _submitError!,
              style: TextStyle(color: scheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
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

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
          letterSpacing: 1.2,
          height: 1.0,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5));
  }
}

class _GoalField extends StatelessWidget {
  const _GoalField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.validator,
    this.decimal = false,
    this.last = false,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final FormFieldValidator<String> validator;
  final bool decimal;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: controller,
          keyboardType: decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffix,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          validator: validator,
        ),
        if (!last) const _SettingsDivider(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Apple Health toggle (iOS only)
// ---------------------------------------------------------------------------

class _AppleHealthToggle extends ConsumerWidget {
  const _AppleHealthToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(appleHealthControllerProvider);
    final enabled = state.value ?? false;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.connectAppleHealthLabel),
      subtitle: Text(l10n.connectAppleHealthDescription),
      value: enabled,
      onChanged: state.isLoading
          ? null
          : (value) =>
              ref.read(appleHealthControllerProvider.notifier).setEnabled(value),
    );
  }
}
