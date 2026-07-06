import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/error_message.dart';
import '../../../core/sync/pull_engine.dart';
import '../../../core/sync/sync_engine_provider.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/unit_converters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/error_view.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../../weight/application/weight_controller.dart';
import '../data/user_details_repository.dart';
import '../domain/user_details.dart';
import 'widgets/confirm_save_details_dialog.dart';
import 'widgets/option_card.dart';

/// Settings > "Body & goals": edits the same `/user-details` fields the
/// onboarding wizard collects, reusing [OptionCard] for the selection
/// pickers. Unlike the wizard, this is a single scrollable page (no
/// step-by-step flow) and never touches weight — that's edited via the
/// dedicated Weight screen.
class OnboardingEditScreen extends ConsumerStatefulWidget {
  const OnboardingEditScreen({super.key});

  @override
  ConsumerState<OnboardingEditScreen> createState() => _OnboardingEditScreenState();
}

class _OnboardingEditScreenState extends ConsumerState<OnboardingEditScreen> {
  Gender? _gender;
  DateTime? _birthDate;
  double? _heightCm;
  ActivityLevel? _activityLevel;
  PrimaryGoal? _primaryGoal;
  double? _targetWeightKg;
  bool _seeded = false;
  bool _saving = false;

  // The as-loaded snapshot, kept aside so _save() can diff the current form
  // state against it and only offer the fields that actually changed.
  UserDetails? _original;

  final _heightCmController = TextEditingController();
  final _feetController = TextEditingController();
  final _inchesController = TextEditingController();
  final _targetKgController = TextEditingController();
  final _targetLbController = TextEditingController();

  @override
  void dispose() {
    _heightCmController.dispose();
    _feetController.dispose();
    _inchesController.dispose();
    _targetKgController.dispose();
    _targetLbController.dispose();
    super.dispose();
  }

  void _seedFrom(UserDetails d, bool isImperial) {
    _original = d;
    _gender = d.gender;
    _birthDate = d.birthDate;
    _heightCm = d.heightCm;
    _activityLevel = d.activityLevel;
    _primaryGoal = d.primaryGoal;
    _targetWeightKg = d.targetWeightKg;
    if (isImperial) {
      final fi = cmToFeetInches(d.heightCm);
      _feetController.text = fi.feet.toString();
      _inchesController.text = fi.inches.toString();
      if (d.targetWeightKg != null) _targetLbController.text = kgToLb(d.targetWeightKg!).toString();
    } else {
      _heightCmController.text = d.heightCm.toString();
      if (d.targetWeightKg != null) _targetKgController.text = d.targetWeightKg!.toString();
    }
    _seeded = true;
  }

  void _onFeetInchesChanged() {
    final feet = int.tryParse(_feetController.text);
    final inches = int.tryParse(_inchesController.text);
    setState(() => _heightCm = feet == null ? null : feetInchesToCm(feet, inches ?? 0));
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: DateTime(now.year - 13, now.month, now.day),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_gender == null ||
        _birthDate == null ||
        _heightCm == null ||
        _activityLevel == null ||
        _primaryGoal == null ||
        _original == null) {
      return;
    }

    final pending = UserDetails(
      gender: _gender!,
      birthDate: _birthDate!,
      heightCm: _heightCm!,
      activityLevel: _activityLevel!,
      primaryGoal: _primaryGoal!,
      targetWeightKg: _targetWeightKg,
    );

    final weights = ref.read(weightControllerProvider).value ?? const [];
    final currentWeightKg = weights.isEmpty
        ? 70.0
        : (weights.toList()..sort((a, b) => a.date.compareTo(b.date))).last.weight;

    final fields = await showConfirmSaveDetailsDialog(
      context,
      original: _original!,
      pending: pending,
      currentWeightKg: currentWeightKg,
    );
    if (fields == null || fields.isEmpty || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(userDetailsRepositoryProvider).patch(pending, fields);
      ref.invalidate(userDetailsProvider);
      ref.invalidate(hasUserDetailsProvider);
      // The recalculated goals landed in user_settings server-side; settings
      // are offline-first (Drift + outbox), so pull the fresh row down —
      // settingsControllerProvider's watch() stream then updates on its own.
      try {
        await ref.read(syncEngineProvider).sync();
        await ref.read(pullEngineProvider).pullAll();
      } catch (_) {
        // Best-effort: no connectivity leaves the local cache briefly stale.
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppSnackbar.showSuccess(context, title: l10n.onboardingDetailsSavedMessage);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final detailsAsync = ref.watch(userDetailsProvider);
    final unitSystem =
        (ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults()).unitSystem;
    final isImperial = unitSystem == UnitSystem.imperial;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.onboardingEditTitle)),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(error: error, onRetry: () => ref.invalidate(userDetailsProvider)),
        data: (details) {
          if (details == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.onboardingNotOnboardedMessage, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.push('/onboarding'),
                      child: Text(l10n.onboardingStartOnboardingButton),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!_seeded) _seedFrom(details, isImperial);
          return _buildForm(context, l10n, isImperial);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, AppLocalizations l10n, bool isImperial) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onboardingGenderLabel, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OptionCard(
                  icon: Icons.male,
                  label: l10n.onboardingGenderMale,
                  active: _gender == Gender.male,
                  onTap: () => setState(() => _gender = Gender.male),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OptionCard(
                  icon: Icons.female,
                  label: l10n.onboardingGenderFemale,
                  active: _gender == Gender.female,
                  onTap: () => setState(() => _gender = Gender.female),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OptionCard(
                  icon: Icons.person,
                  label: l10n.onboardingGenderUnspecified,
                  active: _gender == Gender.unspecified,
                  onTap: () => setState(() => _gender = Gender.unspecified),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l10n.onboardingBirthDateLabel, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickBirthDate,
            icon: const Icon(Icons.calendar_today),
            label: Text(_birthDate == null
                ? l10n.onboardingBirthDateLabel
                : '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}'),
          ),
          const SizedBox(height: 24),
          Text(l10n.onboardingHeightLabel, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (isImperial)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _feetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(suffixText: l10n.onboardingFeetSuffix, border: const OutlineInputBorder()),
                    onChanged: (_) => _onFeetInchesChanged(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _inchesController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(suffixText: l10n.onboardingInchesSuffix, border: const OutlineInputBorder()),
                    onChanged: (_) => _onFeetInchesChanged(),
                  ),
                ),
              ],
            )
          else
            TextField(
              controller: _heightCmController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: 'cm', border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _heightCm = double.tryParse(v.replaceAll(',', '.'))),
            ),
          const SizedBox(height: 24),
          Text(l10n.onboardingActivityLevelLabel, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              for (final a in ActivityLevel.values)
                OptionCard(
                  icon: _activityIcon(a),
                  label: _activityLabel(l10n, a),
                  description: _activityDescription(l10n, a),
                  active: _activityLevel == a,
                  onTap: () => setState(() => _activityLevel = a),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l10n.onboardingPrimaryGoalLabel, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final g in PrimaryGoal.values) ...[
                Expanded(
                  child: OptionCard(
                    icon: _goalIcon(g),
                    label: _goalLabel(l10n, g),
                    active: _primaryGoal == g,
                    onTap: () => setState(() => _primaryGoal = g),
                  ),
                ),
                if (g != PrimaryGoal.values.last) const SizedBox(width: 10),
              ],
            ],
          ),
          if (_primaryGoal != null && _primaryGoal != PrimaryGoal.maintain) ...[
            const SizedBox(height: 24),
            Text(l10n.onboardingTargetWeightOptionalLabel,
                style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            if (isImperial)
              TextField(
                controller: _targetLbController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(suffixText: 'lb', border: OutlineInputBorder()),
                onChanged: (v) {
                  final lb = double.tryParse(v.replaceAll(',', '.'));
                  setState(() => _targetWeightKg = lb == null ? null : lbToKg(lb));
                },
              )
            else
              TextField(
                controller: _targetKgController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(suffixText: 'kg', border: OutlineInputBorder()),
                onChanged: (v) => setState(
                  () => _targetWeightKg = v.trim().isEmpty ? null : double.tryParse(v.replaceAll(',', '.')),
                ),
              ),
          ],
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.input)),
            ),
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.saveButton),
          ),
        ],
      ),
    );
  }

  String _activityLabel(AppLocalizations l10n, ActivityLevel a) => switch (a) {
        ActivityLevel.sedentary => l10n.onboardingActivitySedentary,
        ActivityLevel.light => l10n.onboardingActivityLight,
        ActivityLevel.moderate => l10n.onboardingActivityModerate,
        ActivityLevel.active => l10n.onboardingActivityActive,
        ActivityLevel.veryActive => l10n.onboardingActivityVeryActive,
      };

  String _activityDescription(AppLocalizations l10n, ActivityLevel a) => switch (a) {
        ActivityLevel.sedentary => l10n.onboardingActivityDescriptionSedentary,
        ActivityLevel.light => l10n.onboardingActivityDescriptionLight,
        ActivityLevel.moderate => l10n.onboardingActivityDescriptionModerate,
        ActivityLevel.active => l10n.onboardingActivityDescriptionActive,
        ActivityLevel.veryActive => l10n.onboardingActivityDescriptionVeryActive,
      };

  IconData _activityIcon(ActivityLevel a) => switch (a) {
        ActivityLevel.sedentary => Icons.weekend,
        ActivityLevel.light => Icons.directions_walk,
        ActivityLevel.moderate => Icons.directions_run,
        ActivityLevel.active => Icons.fitness_center,
        ActivityLevel.veryActive => Icons.bolt,
      };

  String _goalLabel(AppLocalizations l10n, PrimaryGoal g) => switch (g) {
        PrimaryGoal.loseWeight => l10n.onboardingGoalLoseWeight,
        PrimaryGoal.maintain => l10n.onboardingGoalMaintain,
        PrimaryGoal.gainMuscle => l10n.onboardingGoalGainMuscle,
      };

  IconData _goalIcon(PrimaryGoal g) => switch (g) {
        PrimaryGoal.loseWeight => Icons.trending_down,
        PrimaryGoal.maintain => Icons.trending_flat,
        PrimaryGoal.gainMuscle => Icons.trending_up,
      };
}
