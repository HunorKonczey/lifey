import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/health/health_controller.dart';
import '../../../core/network/error_message.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/unit_converters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../../weight/application/weight_controller.dart';
import '../data/user_details_repository.dart';
import '../domain/user_details.dart';
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

  // Health step only makes sense on iOS (HealthKit); Android has no
  // equivalent wired up yet, so the wizard is one step shorter there.
  int get _stepCount => Platform.isIOS ? 6 : 5;

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
    await _pageController.nextPage(duration: AppDuration.base, curve: AppCurve.standard);
    if (_step == _suggestedPlanIndex && !_suggestRequested) {
      _suggestRequested = true;
      unawaited(_fetchSuggestion());
    }
  }

  Future<void> _back() async {
    if (_step == 0) return;
    await _pageController.previousPage(duration: AppDuration.base, curve: AppCurve.standard);
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
      if (Platform.isIOS) {
        // One more step (Apple Health) still needs to run before we're
        // actually done — it drives its own exit to /dashboard.
        await _pageController.nextPage(duration: AppDuration.base, curve: AppCurve.standard);
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress dots + skip ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  for (var i = 0; i < _stepCount; i++) ...[
                    AnimatedContainer(
                      duration: AppDuration.fast,
                      curve: AppCurve.standard,
                      width: i == _step ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i <= _step ? scheme.primary : scheme.surfaceContainerHighest,
                        borderRadius: AppRadius.pill,
                      ),
                    ),
                    if (i != _stepCount - 1) const SizedBox(width: 6),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: _skip,
                    child: Text(l10n.onboardingSkipButton),
                  ),
                ],
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
                  ),
                  if (Platform.isIOS)
                    _AppleHealthStep(l10n: l10n, onFinish: _goToDashboard),
                ],
              ),
            ),

            if (_stepError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _stepError!,
                  style: TextStyle(color: scheme.error),
                  textAlign: TextAlign.center,
                ),
              ),

            // ── Nav buttons ──────────────────────────────────────────────
            // Past the suggested-plan step (i.e. the Apple Health step, iOS
            // only) has its own Enable/Not-now controls in the step body, so
            // this shared bar hides itself there instead of duplicating them.
            if (_step <= _suggestedPlanIndex)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    if (_step > 0)
                      TextButton(onPressed: _back, child: Text(l10n.onboardingBackButton))
                    else
                      const SizedBox(width: 8),
                    const Spacer(),
                    if (_step < _suggestedPlanIndex)
                      FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(120, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(_step == 0 ? l10n.onboardingGetStartedButton : l10n.onboardingNextButton),
                      )
                    else
                      Row(
                        children: [
                          TextButton(
                            onPressed: _finishing ? null : () => _finish(applyGoals: false),
                            child: Text(l10n.onboardingNotNowButton),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: (_finishing || _suggestion == null)
                                ? null
                                : () => _finish(applyGoals: true),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(120, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _finishing
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(l10n.onboardingApplyGoalsButton),
                          ),
                        ],
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

// ---------------------------------------------------------------------------
// Step 1 — Welcome
// ---------------------------------------------------------------------------

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco, size: 56, color: scheme.primary),
            const SizedBox(height: 20),
            Text(
              l10n.onboardingWelcomeTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.onboardingWelcomeMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
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
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onboardingAboutYouTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          Text(l10n.onboardingGenderLabel, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
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
          Text(l10n.onboardingBirthDateLabel, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _pickBirthDate(context),
            icon: const Icon(Icons.calendar_today),
            label: Text(birthDate == null
                ? l10n.onboardingBirthDateLabel
                : '${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}'),
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
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onboardingBodyTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          Text(l10n.onboardingHeightLabel, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (isImperial)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: feetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      suffixText: l10n.onboardingFeetSuffix,
                      border: const OutlineInputBorder(),
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
                      suffixText: l10n.onboardingInchesSuffix,
                      border: const OutlineInputBorder(),
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
              decoration: const InputDecoration(suffixText: 'cm', border: OutlineInputBorder()),
              onChanged: (v) => onHeightChanged(double.tryParse(v.replaceAll(',', '.'))),
            ),
          const SizedBox(height: 24),
          Text(l10n.onboardingCurrentWeightLabel, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (isImperial)
            TextField(
              controller: weightLbController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: 'lb', border: OutlineInputBorder()),
              onChanged: (v) {
                final lb = double.tryParse(v.replaceAll(',', '.'));
                onWeightChanged(lb == null ? null : lbToKg(lb));
              },
            )
          else
            TextField(
              controller: weightKgController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: 'kg', border: OutlineInputBorder()),
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
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onboardingLifestyleTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
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
                  label: _activityLabel(a),
                  description: _activityDescription(a),
                  active: activityLevel == a,
                  onTap: () => onActivityChanged(a),
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
                    label: _goalLabel(g),
                    active: primaryGoal == g,
                    onTap: () => onGoalChanged(g),
                  ),
                ),
                if (g != PrimaryGoal.values.last) const SizedBox(width: 10),
              ],
            ],
          ),
          if (primaryGoal != null && primaryGoal != PrimaryGoal.maintain) ...[
            const SizedBox(height: 24),
            Text(l10n.onboardingTargetWeightOptionalLabel,
                style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            if (isImperial)
              TextField(
                controller: targetLbController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(suffixText: 'lb', border: OutlineInputBorder()),
                onChanged: (v) {
                  final lb = double.tryParse(v.replaceAll(',', '.'));
                  onTargetWeightChanged(lb == null ? null : lbToKg(lb));
                },
              )
            else
              TextField(
                controller: targetKgController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(suffixText: 'kg', border: OutlineInputBorder()),
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
  });

  final AppLocalizations l10n;
  final bool suggesting;
  final SuggestGoalsResult? suggestion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mc = context.metricColors;

    if (suggesting || suggestion == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.onboardingCalculatingMessage, style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    final s = suggestion!;
    final metrics = [
      (l10n.caloriesLabel, s.calories.toString(), 'kcal', mc.calories, Icons.local_fire_department),
      (l10n.proteinLabel, s.proteinGrams.toString(), 'g', mc.protein, Icons.egg_alt),
      (l10n.carbsLabel, s.carbsGrams.toString(), 'g', mc.carbs, Icons.bakery_dining),
      (l10n.fatLabel, s.fatGrams.toString(), 'g', mc.fat, Icons.water_drop),
      (l10n.waterLabel, s.waterLiters.toStringAsFixed(1), 'L', mc.water, Icons.water_drop_outlined),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onboardingSuggestedTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            l10n.onboardingSuggestedFromMessage(s.bmr, s.tdee),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.7,
            children: [
              for (final (label, value, unit, color, icon) in metrics)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(height: 6),
                      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
                      Text('$value $unit', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(l10n.onboardingChangeLaterMessage, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 6 — Apple Health (iOS only)
// ---------------------------------------------------------------------------

class _AppleHealthStep extends ConsumerStatefulWidget {
  const _AppleHealthStep({required this.l10n, required this.onFinish});

  final AppLocalizations l10n;
  final VoidCallback onFinish;

  @override
  ConsumerState<_AppleHealthStep> createState() => _AppleHealthStepState();
}

class _AppleHealthStepState extends ConsumerState<_AppleHealthStep> {
  bool _enabling = false;

  Future<void> _enable() async {
    setState(() => _enabling = true);
    try {
      // Requests HealthKit permission and — per AppleHealthController —
      // immediately kicks off a weight + step-history import in the
      // background, so the wizard doesn't need to wait for it here.
      await ref.read(appleHealthControllerProvider.notifier).setEnabled(true);
    } finally {
      if (mounted) setState(() => _enabling = false);
    }
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = widget.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, size: 56, color: scheme.primary),
            const SizedBox(height: 20),
            Text(
              l10n.onboardingHealthTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.onboardingHealthMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _enabling ? null : _enable,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _enabling
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.onboardingHealthEnableButton),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _enabling ? null : widget.onFinish,
              child: Text(l10n.onboardingNotNowButton),
            ),
          ],
        ),
      ),
    );
  }
}
