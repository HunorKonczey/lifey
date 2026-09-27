import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/user_details_repository.dart';
import '../../domain/user_details.dart';

/// Confirmation popup shown after editing "Body & goals": lists only the
/// fields that actually changed (each with a checkbox, default checked),
/// and lets the user pick which of them to persist. Also shows a live
/// recalculated goals preview (calories/protein/carbs/fat/water) based on
/// the currently-selected fields.
///
/// Returns the selected fields on confirm, or `null` if cancelled/dismissed.
Future<Set<UserDetailsField>?> showConfirmSaveDetailsDialog(
  BuildContext context, {
  required UserDetails original,
  required UserDetails pending,
  required double currentWeightKg,
}) {
  return showDialog<Set<UserDetailsField>>(
    context: context,
    builder: (ctx) => _ConfirmSaveDetailsDialog(
      original: original,
      pending: pending,
      currentWeightKg: currentWeightKg,
    ),
  );
}

class _FieldDiff {
  const _FieldDiff({required this.field, required this.label, required this.from, required this.to});

  final UserDetailsField field;
  final String label;
  final String from;
  final String to;
}

class _ConfirmSaveDetailsDialog extends ConsumerStatefulWidget {
  const _ConfirmSaveDetailsDialog({
    required this.original,
    required this.pending,
    required this.currentWeightKg,
  });

  final UserDetails original;
  final UserDetails pending;
  final double currentWeightKg;

  @override
  ConsumerState<_ConfirmSaveDetailsDialog> createState() => _ConfirmSaveDetailsDialogState();
}

class _ConfirmSaveDetailsDialogState extends ConsumerState<_ConfirmSaveDetailsDialog> {
  late List<_FieldDiff> _diffs;
  late Set<UserDetailsField> _selected;
  SuggestGoalsResult? _preview;
  bool _previewLoading = false;
  bool _initialized = false;

  // AppLocalizations.of(context) depends on an InheritedWidget, which isn't
  // available yet in initState() — do the one-time setup here instead, the
  // first time dependencies are resolved.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _diffs = _computeDiffs(context);
    _selected = _diffs.map((d) => d.field).toSet();
    _fetchPreview();
  }

  List<_FieldDiff> _computeDiffs(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final o = widget.original;
    final p = widget.pending;
    final diffs = <_FieldDiff>[];

    if (p.gender != o.gender) {
      diffs.add(_FieldDiff(
        field: UserDetailsField.gender, label: l10n.onboardingGenderLabel,
        from: _genderLabel(l10n, o.gender), to: _genderLabel(l10n, p.gender),
      ));
    }
    if (p.birthDate != o.birthDate) {
      diffs.add(_FieldDiff(
        field: UserDetailsField.birthDate, label: l10n.onboardingBirthDateLabel,
        from: formatDateOnly(o.birthDate), to: formatDateOnly(p.birthDate),
      ));
    }
    if (p.heightCm != o.heightCm) {
      diffs.add(_FieldDiff(
        field: UserDetailsField.heightCm, label: l10n.onboardingHeightLabel,
        from: '${o.heightCm} cm', to: '${p.heightCm} cm',
      ));
    }
    if (p.activityLevel != o.activityLevel) {
      diffs.add(_FieldDiff(
        field: UserDetailsField.activityLevel, label: l10n.onboardingActivityLevelLabel,
        from: _activityLabel(l10n, o.activityLevel), to: _activityLabel(l10n, p.activityLevel),
      ));
    }
    if (p.primaryGoal != o.primaryGoal) {
      diffs.add(_FieldDiff(
        field: UserDetailsField.primaryGoal, label: l10n.onboardingPrimaryGoalLabel,
        from: _goalLabel(l10n, o.primaryGoal), to: _goalLabel(l10n, p.primaryGoal),
      ));
    }
    if (p.targetWeightKg != o.targetWeightKg) {
      diffs.add(_FieldDiff(
        field: UserDetailsField.targetWeightKg, label: l10n.onboardingTargetWeightOptionalLabel,
        from: o.targetWeightKg != null ? '${o.targetWeightKg} kg' : '—',
        to: p.targetWeightKg != null ? '${p.targetWeightKg} kg' : '—',
      ));
    }
    return diffs;
  }

  UserDetails get _merged => UserDetails(
        gender: _selected.contains(UserDetailsField.gender) ? widget.pending.gender : widget.original.gender,
        birthDate:
            _selected.contains(UserDetailsField.birthDate) ? widget.pending.birthDate : widget.original.birthDate,
        heightCm: _selected.contains(UserDetailsField.heightCm) ? widget.pending.heightCm : widget.original.heightCm,
        activityLevel: _selected.contains(UserDetailsField.activityLevel)
            ? widget.pending.activityLevel
            : widget.original.activityLevel,
        primaryGoal: _selected.contains(UserDetailsField.primaryGoal)
            ? widget.pending.primaryGoal
            : widget.original.primaryGoal,
        targetWeightKg: _selected.contains(UserDetailsField.targetWeightKg)
            ? widget.pending.targetWeightKg
            : widget.original.targetWeightKg,
      );

  Future<void> _fetchPreview() async {
    setState(() => _previewLoading = true);
    final merged = _merged;
    try {
      final result = await ref.read(userDetailsRepositoryProvider).suggestGoals(
            gender: merged.gender,
            birthDate: merged.birthDate,
            heightCm: merged.heightCm,
            weightKg: widget.currentWeightKg,
            activityLevel: merged.activityLevel,
            primaryGoal: merged.primaryGoal,
          );
      if (mounted) setState(() => _preview = result);
    } catch (_) {
      if (mounted) setState(() => _preview = null);
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  void _toggle(UserDetailsField field) {
    setState(() {
      if (_selected.contains(field)) {
        _selected.remove(field);
      } else {
        _selected.add(field);
      }
    });
    _fetchPreview();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // AlertDialog (rather than a hand-rolled Dialog+Flexible+ScrollView) so
    // the framework — not custom layout math — handles sizing the scrollable
    // content against the fixed title/actions, which is what was making the
    // action buttons unreliable to tap (they could end up laid out outside
    // their actual hit-test area when content overflowed the guessed height).
    // Surface, radius, title and body styles come from the dialog theme
    // (canvas: logout dialog).
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s24),
      titlePadding: const EdgeInsets.fromLTRB(AppSpacing.s24, AppSpacing.s24, AppSpacing.s24, 0),
      contentPadding: const EdgeInsets.fromLTRB(AppSpacing.s24, AppSpacing.s12, AppSpacing.s24, 0),
      scrollable: true,
      title: Text(l10n.onboardingConfirmSaveTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_diffs.isEmpty)
              Text(l10n.onboardingConfirmSaveNoChangesMessage)
            else ...[
              Text(l10n.onboardingConfirmSaveIntroMessage),
              const SizedBox(height: AppSpacing.s16),
              for (final diff in _diffs)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                  // Material (not a colored Container/DecoratedBox) so
                  // ListTile's own background/ink-splash painting has a
                  // Material ancestor to paint onto directly — a colored
                  // Container in between makes Flutter throw an assertion
                  // on every build (including the dialog's close/dismiss
                  // transition), which was aborting the pop and making the
                  // action buttons look unresponsive.
                  child: Material(
                    color: p.nested,
                    borderRadius: AppRadius.controlAll,
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s4),
                      child: CheckboxListTile(
                        value: _selected.contains(diff.field),
                        onChanged: (_) => _toggle(diff.field),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: scheme.primary,
                        title: Text(diff.label, style: t.labelMedium!.copyWith(color: p.text2)),
                        subtitle: Text('${diff.from} → ${diff.to}', style: t.titleSmall!.copyWith(color: p.text)),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.s8),
              Text(l10n.onboardingRecalculatedGoalsLabel, style: t.labelLarge!.copyWith(color: p.text2)),
              const SizedBox(height: AppSpacing.s8),
              if (_previewLoading || _preview == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
                  child: Text(l10n.onboardingCalculatingMessage, textAlign: TextAlign.center),
                )
              else
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    _GoalChip(label: l10n.caloriesLabel, value: '${_preview!.calories} kcal'),
                    _GoalChip(label: l10n.proteinLabel, value: '${_preview!.proteinGrams} g'),
                    _GoalChip(label: l10n.carbsLabel, value: '${_preview!.carbsGrams} g'),
                    _GoalChip(label: l10n.fatLabel, value: '${_preview!.fatGrams} g'),
                    _GoalChip(label: l10n.waterLabel, value: '${_preview!.waterLiters} L'),
                  ],
                ),
            ],
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: p.nested,
                    foregroundColor: p.text,
                    side: BorderSide(color: context.elevation.border),
                  ),
                  child: Text(l10n.cancelButton),
                ),
              ),
            ),
            if (_diffs.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected),
                    child: Text(l10n.saveButton),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _genderLabel(AppLocalizations l10n, Gender g) => switch (g) {
        Gender.male => l10n.onboardingGenderMale,
        Gender.female => l10n.onboardingGenderFemale,
        Gender.unspecified => l10n.onboardingGenderUnspecified,
      };

  String _activityLabel(AppLocalizations l10n, ActivityLevel a) => switch (a) {
        ActivityLevel.sedentary => l10n.onboardingActivitySedentary,
        ActivityLevel.light => l10n.onboardingActivityLight,
        ActivityLevel.moderate => l10n.onboardingActivityModerate,
        ActivityLevel.active => l10n.onboardingActivityActive,
        ActivityLevel.veryActive => l10n.onboardingActivityVeryActive,
      };

  String _goalLabel(AppLocalizations l10n, PrimaryGoal g) => switch (g) {
        PrimaryGoal.loseWeight => l10n.onboardingGoalLoseWeight,
        PrimaryGoal.maintain => l10n.onboardingGoalMaintain,
        PrimaryGoal.gainMuscle => l10n.onboardingGoalGainMuscle,
      };
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
      decoration: BoxDecoration(color: p.nested, borderRadius: AppRadius.controlAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: t.labelSmall!.copyWith(color: p.text2)),
          Text(value, style: t.titleSmall!.copyWith(color: p.text)),
        ],
      ),
    );
  }
}
