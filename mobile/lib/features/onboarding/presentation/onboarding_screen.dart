import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/lifey_format.dart';
import '../../../core/health/health_controller.dart';
import '../../../core/network/error_message.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../core/utils/unit_converters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/ds/lifey_card.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/ds/metric_bar.dart';
import '../../../shared/widgets/ds/metric_value.dart';
import '../../../shared/widgets/ds/screen_heading.dart';
import '../../../shared/widgets/ds/section_label.dart';
import '../../../shared/widgets/ds/tinted_chip.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../../weight/application/weight_controller.dart';
import '../data/user_details_repository.dart';
import '../domain/plan_shares.dart';
import '../domain/user_details.dart';
import 'widgets/date_row.dart';
import 'widgets/option_card.dart';

// Welcome, About you, Body, Lifestyle & goal, Suggested plan, [Apple Health — iOS only]
const int _suggestedPlanIndex = 4;

/// 5-step onboarding wizard: collects biometrics, previews suggested daily
/// goals, and lets the user apply them or skip. See
/// docs/21-onboarding-user-details-plan.md for the full spec.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;

  Gender? _gender;
  DateTime? _birthDate;
  double? _heightCm;
  double? _weightKg;
  ActivityLevel? _activityLevel;
  PrimaryGoal? _primaryGoal;
  double? _targetWeightKg;

  final _feetController = TextEditingController();
  final _inchesController = TextEditingController();
  final _weightLbController = TextEditingController();
  final _targetLbController = TextEditingController();
  final _heightCmController = TextEditingController();
  final _weightKgController = TextEditingController();
  final _targetKgController = TextEditingController();

  String? _stepError;
  SuggestGoalsResult? _suggestion;
  bool _suggesting = false;
  bool _suggestRequested = false;
  bool _finishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    _feetController.dispose();
    _inchesController.dispose();
    _weightLbController.dispose();
    _targetLbController.dispose();
    _heightCmController.dispose();
    _weightKgController.dispose();
    _targetKgController.dispose();
    super.dispose();
  }

  // Health step needs a platform health store to connect to — HealthKit on
  // iOS, Health Connect on Android (docs/26-android-health-connect-integration-plan.md).
  int get _stepCount => (Platform.isIOS || Platform.isAndroid) ? 6 : 5;

  bool get _isImperial =>
      (ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults())
          .unitSystem ==
      UnitSystem.imperial;

  int _ageFor(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  bool _validateStep(AppLocalizations l10n) {
    setState(() => _stepError = null);
    switch (_step) {
      case 1:
        if (_gender == null) {
          setState(() => _stepError = l10n.onboardingRequiredFieldError);
          return false;
        }
        if (_birthDate == null || _birthDate!.isAfter(DateTime.now())) {
          setState(() => _stepError = l10n.onboardingInvalidBirthDateError);
          return false;
        }
        final age = _ageFor(_birthDate!);
        if (age < 13 || age > 120) {
          setState(() => _stepError = l10n.onboardingInvalidBirthDateError);
          return false;
        }
        return true;
      case 2:
        if (_heightCm == null || _heightCm! < 80 || _heightCm! > 250) {
          setState(() => _stepError = l10n.onboardingHeightRangeError);
          return false;
        }
        if (_weightKg == null || _weightKg! < 30 || _weightKg! > 300) {
          setState(() => _stepError = l10n.onboardingWeightRangeError);
          return false;
        }
        return true;
      case 3:
        if (_activityLevel == null || _primaryGoal == null) {
          setState(() => _stepError = l10n.onboardingRequiredFieldError);
          return false;
        }
        if (_targetWeightKg != null && (_targetWeightKg! < 30 || _targetWeightKg! > 300)) {
          setState(() => _stepError = l10n.onboardingWeightRangeError);
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context)!;
    if (_step > 0 && !_validateStep(l10n)) return;
    if (_step >= _stepCount - 1) return;
    await _pageController.nextPage(duration: AppMotion.of(context, AppMotion.page), curve: AppMotion.standard);
    if (_step == _suggestedPlanIndex && !_suggestRequested) {
      _suggestRequested = true;
      unawaited(_fetchSuggestion());
    }
  }

  Future<void> _back() async {
    if (_step == 0) return;
    await _pageController.previousPage(duration: AppMotion.of(context, AppMotion.page), curve: AppMotion.standard);
  }

  Future<void> _fetchSuggestion() async {
    if (_gender == null ||
        _birthDate == null ||
        _heightCm == null ||
        _weightKg == null ||
        _activityLevel == null ||
        _primaryGoal == null) {
      return;
    }
    setState(() {
      _suggesting = true;
      _suggestion = null;
    });
    try {
      final result = await ref.read(userDetailsRepositoryProvider).suggestGoals(
            gender: _gender!,
            birthDate: _birthDate!,
            heightCm: _heightCm!,
            weightKg: _weightKg!,
            activityLevel: _activityLevel!,
            primaryGoal: _primaryGoal!,
          );
      if (mounted) setState(() => _suggestion = result);
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppSnackbar.showError(context, title: l10n.onboardingSuggestFailedMessage);
      }
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  void _skip() => context.go('/dashboard');

  Future<void> _finish({required bool applyGoals}) async {
    if (_finishing) return;
    if (_gender == null ||
        _birthDate == null ||
        _heightCm == null ||
        _weightKg == null ||
        _activityLevel == null ||
        _primaryGoal == null) {
      return;
    }
    setState(() => _finishing = true);
    try {
      await ref.read(userDetailsRepositoryProvider).upsert(UserDetails(
            gender: _gender!,
            birthDate: _birthDate!,
            heightCm: _heightCm!,
            activityLevel: _activityLevel!,
            primaryGoal: _primaryGoal!,
            targetWeightKg: _targetWeightKg,
          ));
      await ref.read(weightControllerProvider.notifier).addEntry(
            date: DateTime.now(),
            weight: _weightKg!,
          );

      if (applyGoals && _suggestion != null) {
        final current = ref.read(settingsControllerProvider).value ?? const UserSettings.defaults();
        await ref.read(settingsControllerProvider.notifier).save(UserSettings(
              unitSystem: current.unitSystem,
              theme: current.theme,
              language: current.language,
              dailyCalorieGoal: _suggestion!.calories,
              dailyProteinGoal: _suggestion!.proteinGrams,
              dailyCarbsGoal: _suggestion!.carbsGrams,
              dailyFatGoal: _suggestion!.fatGrams,
              dailyWaterGoalLiters: _suggestion!.waterLiters,
              dailyStepGoal: current.dailyStepGoal,
            ));
      }

      ref.invalidate(userDetailsProvider);
      ref.invalidate(hasUserDetailsProvider);
      if (!mounted) return;
      if (Platform.isIOS || Platform.isAndroid) {
        // One more step (Health) still needs to run before we're actually
        // done — it drives its own exit to /dashboard.
        await _pageController.nextPage(duration: AppMotion.of(context, AppMotion.page), curve: AppMotion.standard);
      } else {
        _goToDashboard();
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  void _goToDashboard() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    AppSnackbar.showSuccess(context, title: l10n.onboardingCompleteMessage);
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final p = context.palette;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Segmented progress + skip ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s16, AppSpacing.s8, 0),
              child: Row(
                children: [
                  Expanded(child: _StepProgress(step: _step, count: _stepCount)),
                  const SizedBox(width: AppSpacing.s8),
                  TextButton(
                    onPressed: _skip,
                    style: TextButton.styleFrom(foregroundColor: p.text2),
                    child: Text(l10n.onboardingSkipButton),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s12, AppSpacing.screen, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.onboardingStepOfLabel(_step + 1, _stepCount),
                  style: t.bodyMedium!.copyWith(color: p.text2),
                ),
              ),
            ),

            // ── Pages ────────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _WelcomeStep(l10n: l10n),
                  _AboutYouStep(
                    l10n: l10n,
                    gender: _gender,
                    birthDate: _birthDate,
                    onGenderChanged: (g) => setState(() => _gender = g),
                    onBirthDateChanged: (d) => setState(() => _birthDate = d),
                  ),
                  _BodyStep(
                    l10n: l10n,
                    isImperial: _isImperial,
                    heightCmController: _heightCmController,
                    weightKgController: _weightKgController,
                    feetController: _feetController,
                    inchesController: _inchesController,
                    weightLbController: _weightLbController,
                    onHeightChanged: (v) => setState(() => _heightCm = v),
                    onWeightChanged: (v) => setState(() => _weightKg = v),
                  ),
                  _LifestyleStep(
                    l10n: l10n,
                    isImperial: _isImperial,
                    activityLevel: _activityLevel,
                    primaryGoal: _primaryGoal,
                    targetKgController: _targetKgController,
                    targetLbController: _targetLbController,
                    onActivityChanged: (v) => setState(() => _activityLevel = v),
                    onGoalChanged: (v) => setState(() => _primaryGoal = v),
                    onTargetWeightChanged: (v) => setState(() => _targetWeightKg = v),
                  ),
                  _SuggestedPlanStep(
                    l10n: l10n,
                    suggesting: _suggesting,
                    suggestion: _suggestion,
                    primaryGoal: _primaryGoal,
                    activityLevel: _activityLevel,
                  ),
                  if (Platform.isIOS || Platform.isAndroid)
                    _HealthStep(l10n: l10n, onFinish: _goToDashboard),
                ],
              ),
            ),

            if (_stepError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                child: Text(
                  _stepError!,
                  style: t.bodyMedium!.copyWith(color: scheme.error),
                  textAlign: TextAlign.center,
                ),
              ),

            // ── Nav buttons ──────────────────────────────────────────────
            // Past the suggested-plan step (i.e. the Health step) has its own
            // Enable / Not-now controls in the step body, so this shared bar
            // hides itself there instead of duplicating them.
            if (_step <= _suggestedPlanIndex)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s12, AppSpacing.screen, AppSpacing.s20),
                child: _step == _suggestedPlanIndex
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PrimaryNavButton(
                            label: l10n.onboardingApplyGoalsButton,
                            loading: _finishing,
                            onPressed: (_finishing || _suggestion == null) ? null : () => _finish(applyGoals: true),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          // "Back" is a quiet button, "Not now" a text action:
                          // both weigh less than "Apply these goals".
                          Row(
                            children: [
                              Expanded(child: _BackButton(label: l10n.onboardingBackButton, onPressed: _finishing ? null : _back)),
                              Expanded(
                                child: TextButton(
                                  onPressed: _finishing ? null : () => _finish(applyGoals: false),
                                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(56), foregroundColor: p.text),
                                  child: Text(l10n.onboardingNotNowButton),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          if (_step > 0) ...[
                            _BackButton(label: l10n.onboardingBackButton, onPressed: _back),
                            const SizedBox(width: AppSpacing.s12),
                          ],
                          Expanded(
                            child: _PrimaryNavButton(
                              label: _step == 0 ? l10n.onboardingGetStartedButton : l10n.onboardingNextButton,
                              onPressed: _next,
                            ),
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One segment per step, the ones reached filled (canvas: "Step 4 of 6").
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final primary = Theme.of(context).colorScheme.primary;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.page),
                curve: AppMotion.standard,
                height: 5,
                decoration: BoxDecoration(color: i <= step ? primary : p.control, borderRadius: AppRadius.pill),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The wizard's forward action: full-width primary, 56 dp.
class _PrimaryNavButton extends StatelessWidget {
  const _PrimaryNavButton({required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: FilledButton(
          onPressed: onPressed,
          child: loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(label),
        ),
      );
}

/// "Back": a quiet 56 dp button on the control surface.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: p.control,
          foregroundColor: p.text,
          side: BorderSide(color: context.elevation.border),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
        ),
        child: Text(label),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — Welcome
// ---------------------------------------------------------------------------

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s32, AppSpacing.screen, AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandTile(),
          const SizedBox(height: AppSpacing.s32),
          ScreenHeading(title: l10n.onboardingWelcomeTitle, subtitle: l10n.onboardingWelcomeMessage),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — About you
// ---------------------------------------------------------------------------

class _AboutYouStep extends StatelessWidget {
  const _AboutYouStep({
    required this.l10n,
    required this.gender,
    required this.birthDate,
    required this.onGenderChanged,
    required this.onBirthDateChanged,
  });

  final AppLocalizations l10n;
  final Gender? gender;
  final DateTime? birthDate;
  final ValueChanged<Gender> onGenderChanged;
  final ValueChanged<DateTime> onBirthDateChanged;

  Future<void> _pickBirthDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birthDate ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: DateTime(now.year - 13, now.month, now.day),
    );
    if (picked != null) onBirthDateChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(title: l10n.onboardingAboutYouTitle),
          const SizedBox(height: AppSpacing.s24),
          SectionLabel(l10n.onboardingGenderLabel),
          const SizedBox(height: 8),
          OptionRow(
            children: [
              Expanded(
                child: OptionCard(
                  icon: Icons.male,
                  label: l10n.onboardingGenderMale,
                  active: gender == Gender.male,
                  onTap: () => onGenderChanged(Gender.male),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OptionCard(
                  icon: Icons.female,
                  label: l10n.onboardingGenderFemale,
                  active: gender == Gender.female,
                  onTap: () => onGenderChanged(Gender.female),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OptionCard(
                  icon: Icons.person,
                  label: l10n.onboardingGenderUnspecified,
                  active: gender == Gender.unspecified,
                  onTap: () => onGenderChanged(Gender.unspecified),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SectionLabel(l10n.onboardingBirthDateLabel),
          const SizedBox(height: 8),
          DateRow(
            onTap: () => _pickBirthDate(context),
            placeholder: birthDate == null,
            text: birthDate == null
                ? l10n.onboardingBirthDateLabel
                : '${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 — Body
// ---------------------------------------------------------------------------

class _BodyStep extends StatelessWidget {
  const _BodyStep({
    required this.l10n,
    required this.isImperial,
    required this.heightCmController,
    required this.weightKgController,
    required this.feetController,
    required this.inchesController,
    required this.weightLbController,
    required this.onHeightChanged,
    required this.onWeightChanged,
  });

  final AppLocalizations l10n;
  final bool isImperial;
  final TextEditingController heightCmController;
  final TextEditingController weightKgController;
  final TextEditingController feetController;
  final TextEditingController inchesController;
  final TextEditingController weightLbController;
  final ValueChanged<double?> onHeightChanged;
  final ValueChanged<double?> onWeightChanged;

  void _onFeetInchesChanged() {
    final feet = int.tryParse(feetController.text);
    final inches = int.tryParse(inchesController.text);
    if (feet == null) {
      onHeightChanged(null);
      return;
    }
    onHeightChanged(feetInchesToCm(feet, inches ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(title: l10n.onboardingBodyTitle),
          const SizedBox(height: AppSpacing.s24),
          SectionLabel(l10n.onboardingHeightLabel),
          const SizedBox(height: 8),
          if (isImperial)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: feetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      suffixIcon: UnitSuffix(l10n.onboardingFeetSuffix), suffixIconConstraints: const BoxConstraints(),
                    ),
                    onChanged: (_) => _onFeetInchesChanged(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: inchesController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      suffixIcon: UnitSuffix(l10n.onboardingInchesSuffix), suffixIconConstraints: const BoxConstraints(),
                    ),
                    onChanged: (_) => _onFeetInchesChanged(),
                  ),
                ),
              ],
            )
          else
            TextField(
              controller: heightCmController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixIcon: UnitSuffix('cm'), suffixIconConstraints: BoxConstraints()),
              onChanged: (v) => onHeightChanged(double.tryParse(v.replaceAll(',', '.'))),
            ),
          const SizedBox(height: 24),
          SectionLabel(l10n.onboardingCurrentWeightLabel),
          const SizedBox(height: 8),
          if (isImperial)
            TextField(
              controller: weightLbController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixIcon: UnitSuffix('lb'), suffixIconConstraints: BoxConstraints()),
              onChanged: (v) {
                final lb = double.tryParse(v.replaceAll(',', '.'));
                onWeightChanged(lb == null ? null : lbToKg(lb));
              },
            )
          else
            TextField(
              controller: weightKgController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixIcon: UnitSuffix('kg'), suffixIconConstraints: BoxConstraints()),
              onChanged: (v) => onWeightChanged(double.tryParse(v.replaceAll(',', '.'))),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 4 — Lifestyle & goal
// ---------------------------------------------------------------------------

class _LifestyleStep extends StatelessWidget {
  const _LifestyleStep({
    required this.l10n,
    required this.isImperial,
    required this.activityLevel,
    required this.primaryGoal,
    required this.targetKgController,
    required this.targetLbController,
    required this.onActivityChanged,
    required this.onGoalChanged,
    required this.onTargetWeightChanged,
  });

  final AppLocalizations l10n;
  final bool isImperial;
  final ActivityLevel? activityLevel;
  final PrimaryGoal? primaryGoal;
  final TextEditingController targetKgController;
  final TextEditingController targetLbController;
  final ValueChanged<ActivityLevel> onActivityChanged;
  final ValueChanged<PrimaryGoal> onGoalChanged;
  final ValueChanged<double?> onTargetWeightChanged;

  String _activityLabel(ActivityLevel a) => switch (a) {
        ActivityLevel.sedentary => l10n.onboardingActivitySedentary,
        ActivityLevel.light => l10n.onboardingActivityLight,
        ActivityLevel.moderate => l10n.onboardingActivityModerate,
        ActivityLevel.active => l10n.onboardingActivityActive,
        ActivityLevel.veryActive => l10n.onboardingActivityVeryActive,
      };

  String _activityDescription(ActivityLevel a) => switch (a) {
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

  String _goalLabel(PrimaryGoal g) => switch (g) {
        PrimaryGoal.loseWeight => l10n.onboardingGoalLoseWeight,
        PrimaryGoal.maintain => l10n.onboardingGoalMaintain,
        PrimaryGoal.gainMuscle => l10n.onboardingGoalGainMuscle,
      };

  IconData _goalIcon(PrimaryGoal g) => switch (g) {
        PrimaryGoal.loseWeight => Icons.trending_down,
        PrimaryGoal.maintain => Icons.trending_flat,
        PrimaryGoal.gainMuscle => Icons.trending_up,
      };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(title: l10n.onboardingLifestyleQuestion),
          const SizedBox(height: AppSpacing.s24),
          for (final a in ActivityLevel.values) ...[
            RadioOptionRow(
              icon: _activityIcon(a),
              title: _activityLabel(a),
              description: _activityDescription(a),
              selected: activityLevel == a,
              onTap: () => onActivityChanged(a),
            ),
            if (a != ActivityLevel.values.last) const SizedBox(height: AppSpacing.s12),
          ],
          const SizedBox(height: AppSpacing.s24),
          SectionLabel(l10n.onboardingPrimaryGoalLabel),
          const SizedBox(height: AppSpacing.s12),
          OptionRow(
            children: [
              for (final g in PrimaryGoal.values) ...[
                Expanded(
                  child: OptionCard(
                    icon: _goalIcon(g),
                    label: _goalLabel(g),
                    active: primaryGoal == g,
                    onTap: () => onGoalChanged(g),
                  ),
                ),
                if (g != PrimaryGoal.values.last) const SizedBox(width: AppSpacing.s8),
              ],
            ],
          ),
          if (primaryGoal != null && primaryGoal != PrimaryGoal.maintain) ...[
            const SizedBox(height: 24),
            SectionLabel(l10n.onboardingTargetWeightOptionalLabel),
            const SizedBox(height: 8),
            if (isImperial)
              TextField(
                controller: targetLbController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(suffixIcon: UnitSuffix('lb'), suffixIconConstraints: BoxConstraints()),
                onChanged: (v) {
                  final lb = double.tryParse(v.replaceAll(',', '.'));
                  onTargetWeightChanged(lb == null ? null : lbToKg(lb));
                },
              )
            else
              TextField(
                controller: targetKgController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(suffixIcon: UnitSuffix('kg'), suffixIconConstraints: BoxConstraints()),
                onChanged: (v) => onTargetWeightChanged(
                  v.trim().isEmpty ? null : double.tryParse(v.replaceAll(',', '.')),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 5 — Suggested plan
// ---------------------------------------------------------------------------

class _SuggestedPlanStep extends StatelessWidget {
  const _SuggestedPlanStep({
    required this.l10n,
    required this.suggesting,
    required this.suggestion,
    required this.primaryGoal,
    required this.activityLevel,
  });

  final AppLocalizations l10n;
  final bool suggesting;
  final SuggestGoalsResult? suggestion;
  final PrimaryGoal? primaryGoal;
  final ActivityLevel? activityLevel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final mc = context.metricColors;
    final f = LifeyFormat.of(context);

    if (suggesting || suggestion == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.s16),
              Text(l10n.onboardingCalculatingMessage, style: t.bodyMedium!.copyWith(color: p.text2)),
            ],
          ),
        ),
      );
    }

    final s = suggestion!;
    final adjust = calorieAdjustmentPercent(calories: s.calories, tdee: s.tdee);
    final shares = macroPercents(proteinGrams: s.proteinGrams, carbsGrams: s.carbsGrams, fatGrams: s.fatGrams);
    final macros = [
      (l10n.proteinLabel, s.proteinGrams, shares[0], mc.protein, 4),
      (l10n.carbsLabel, s.carbsGrams, shares[1], mc.carbs, 4),
      (l10n.fatLabel, s.fatGrams, shares[2], mc.fat, 9),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeading(
            title: l10n.onboardingSuggestedTitle,
            subtitle: primaryGoal == null || activityLevel == null
                ? null
                : l10n.onboardingSuggestedSubtitle(primaryGoal!.name, activityLevel!.name),
          ),
          const SizedBox(height: AppSpacing.s24),
          LifeyCard.hero(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 20, color: mc.calories),
                    const SizedBox(width: AppSpacing.s8),
                    Text(l10n.onboardingDailyCaloriesLabel, style: t.labelLarge!.copyWith(color: p.text2)),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: MetricValue(value: f.integer(s.calories), unit: 'kcal', size: 60),
                ),
                const SizedBox(height: AppSpacing.s16),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    TintedChip(label: l10n.onboardingChipBmr(f.integer(s.bmr)), color: p.text2),
                    TintedChip(label: l10n.onboardingChipTdee(f.integer(s.tdee)), color: p.text2),
                    TintedChip(
                      label: adjust > 0
                          ? l10n.onboardingChipSurplus(adjust)
                          : adjust < 0
                              ? l10n.onboardingChipDeficit(-adjust)
                              : l10n.onboardingChipMaintenance,
                      color: p.text2,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s20),
                RatioBar(
                  segments: [for (final m in macros) (value: (m.$2 * m.$5).toDouble(), color: m.$4)],
                ),
                const SizedBox(height: AppSpacing.s16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final m in macros)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.$1, style: t.labelLarge!.copyWith(color: m.$4)),
                            const SizedBox(height: AppSpacing.s4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              // The unit at the number's own size — "129 g".
                              child: Text(
                                '${f.integer(m.$2)} g',
                                maxLines: 1,
                                textScaler: AppType.noScale(context),
                                style: AppType.number(26, color: p.text),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            Text('${m.$3}%', style: t.bodyMedium!.copyWith(color: p.text2)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          LifeyCard(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Row(
              children: [
                ListIconHolder(icon: Icons.water_drop_rounded, color: mc.water),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.waterLabel, style: t.labelLarge!.copyWith(color: p.text2)),
                      const SizedBox(height: AppSpacing.s4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: MetricValue(
                          value: f.decimal(s.waterLiters, 1),
                          unit: 'L ${l10n.onboardingWaterPerDay}',
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Text(l10n.onboardingChangeLaterMessage, style: t.bodyMedium!.copyWith(color: p.text2)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 6 — Health (iOS: Apple Health, Android: Health Connect)
// ---------------------------------------------------------------------------

class _HealthStep extends ConsumerStatefulWidget {
  const _HealthStep({required this.l10n, required this.onFinish});

  final AppLocalizations l10n;
  final VoidCallback onFinish;

  @override
  ConsumerState<_HealthStep> createState() => _HealthStepState();
}

class _HealthStepState extends ConsumerState<_HealthStep> {
  bool _enabling = false;

  Future<void> _enable() async {
    setState(() => _enabling = true);
    try {
      // Requests platform health permission and — per HealthController —
      // immediately kicks off a weight + step-history import in the
      // background, so the wizard doesn't need to wait for it here. On
      // Android, if Health Connect isn't installed yet, this instead opens
      // the Play Store and leaves the toggle off; the user can retry from
      // Settings once it's installed.
      await ref.read(healthControllerProvider.notifier).setEnabled(true);
    } finally {
      if (mounted) setState(() => _enabling = false);
    }
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s32, AppSpacing.screen, AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandTile(icon: Icons.favorite_rounded),
                const SizedBox(height: AppSpacing.s32),
                ScreenHeading(title: l10n.onboardingHealthTitle, subtitle: l10n.onboardingHealthMessage),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s12, AppSpacing.screen, AppSpacing.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PrimaryNavButton(label: l10n.onboardingHealthEnableButton, loading: _enabling, onPressed: _enabling ? null : _enable),
              const SizedBox(height: AppSpacing.s8),
              // Leaves the connection off: nothing is requested or stored.
              TextButton(
                onPressed: _enabling ? null : widget.onFinish,
                style: TextButton.styleFrom(minimumSize: const Size.fromHeight(56), foregroundColor: context.palette.text),
                child: Text(l10n.onboardingNotNowButton),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
