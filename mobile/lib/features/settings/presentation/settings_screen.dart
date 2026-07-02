import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/health/health_controller.dart';
import '../../../core/network/error_message.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/change_password_screen.dart';
import '../../onboarding/presentation/onboarding_edit_screen.dart';
import '../../water/presentation/water_sources_screen.dart';
import '../application/settings_controller.dart';
import '../domain/user_settings.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Form state (initialized on first data load)
  bool _initialized = false;
  late UnitSystem _unitSystem;
  late ThemePreference _theme;
  late LanguagePreference _language;
  int? _calorieGoal;
  int? _proteinGoal;
  int? _carbsGoal;
  int? _fatGoal;
  double? _waterGoal;
  int? _stepGoal;

  void _initFromSettings(UserSettings s) {
    _unitSystem = s.unitSystem;
    _theme = s.theme;
    _language = s.language;
    _calorieGoal = s.dailyCalorieGoal;
    _proteinGoal = s.dailyProteinGoal;
    _carbsGoal = s.dailyCarbsGoal;
    _fatGoal = s.dailyFatGoal;
    _waterGoal = s.dailyWaterGoalLiters;
    _stepGoal = s.dailyStepGoal;
    _initialized = true;
  }

  void _autoSave() {
    ref
        .read(settingsControllerProvider.notifier)
        .save(
          UserSettings(
            unitSystem: _unitSystem,
            theme: _theme,
            language: _language,
            dailyCalorieGoal: _calorieGoal,
            dailyProteinGoal: _proteinGoal,
            dailyCarbsGoal: _carbsGoal,
            dailyFatGoal: _fatGoal,
            dailyWaterGoalLiters: _waterGoal,
            dailyStepGoal: _stepGoal,
          ),
        )
        .catchError((e) {
          if (mounted) {
            AppSnackbar.showError(context, title: friendlyError(e));
          }
        });
  }

  // Opens a bottom-sheet picker for Language.
  void _pickLanguage(AppLocalizations l10n) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in LanguagePreference.values)
              ListTile(
                title: Text(_languageName(opt, l10n)),
                trailing:
                    _language == opt
                        ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                        : null,
                onTap: () {
                  setState(() => _language = opt);
                  _autoSave();
                  Navigator.of(sheetCtx).pop();
                },
              ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
          ],
        );
      },
    );
  }

  // Opens a bottom-sheet text editor for a numeric goal field.
  void _openGoalSheet({
    required String label,
    required String suffix,
    required String initialText,
    required bool decimal,
    required void Function(String text) onSave,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _GoalEditSheet(
        label: label,
        suffix: suffix,
        initialText: initialText,
        decimal: decimal,
        onSave: (text) {
          onSave(text);
          _autoSave();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsControllerProvider);
    final email = ref.watch(authControllerProvider).value?.email;
    final l10n = AppLocalizations.of(context)!;

    // Initialize form state once on first successful load.
    if (!_initialized) {
      state.whenData(_initFromSettings);
    }

    final statusTop = MediaQuery.paddingOf(context).top;
    final barTop = statusTop + 8.0;
    final contentTop = barTop + 58.0 + 12.0;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: state.when(
        data:
            (_) =>
                _initialized
                    ? _buildContent(
                      context,
                      l10n,
                      barTop,
                      contentTop,
                      bottomPad,
                      email,
                    )
                    : const Center(child: CircularProgressIndicator()),
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => ErrorView(
              error: error,
              onRetry: () => ref.invalidate(settingsControllerProvider),
            ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    double barTop,
    double contentTop,
    double bottomPad,
    String? email,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final mc = context.metricColors;

    return ScrollCollapseListener(
      child: Stack(
        children: [
          // ── Scrollable body ─────────────────────────────────────────────
          Positioned.fill(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, contentTop, 16, bottomPad + 32),
              children: [
                // ── Preferences ────────────────────────────────────────────
                _GroupLabel(l10n.preferencesLabel),
                const SizedBox(height: 8),
                _SettingsCard(
                  children: [
                    // Units
                    _SettingRow(
                      icon: Icons.straighten,
                      iconColor: scheme.primary,
                      label: l10n.unitsLabel,
                      trailing: _InlinePillSegment<UnitSystem>(
                        options: [
                          (UnitSystem.metric, l10n.unitsMetricShort),
                          (UnitSystem.imperial, l10n.unitsImperialShort),
                        ],
                        selected: _unitSystem,
                        onChanged: (v) {
                          setState(() => _unitSystem = v);
                          _autoSave();
                        },
                      ),
                    ),
                    const _RowDivider(),
                    // Theme
                    _SettingRow(
                      icon: Icons.dark_mode_outlined,
                      iconColor: scheme.primary,
                      label: l10n.themeLabel,
                      trailing: _InlinePillSegment<ThemePreference>(
                        options: [
                          (ThemePreference.light, l10n.themeLight),
                          (ThemePreference.dark, l10n.themeDark),
                          (ThemePreference.system, l10n.optionSystem),
                        ],
                        selected: _theme,
                        onChanged: (v) {
                          setState(() => _theme = v);
                          _autoSave();
                        },
                      ),
                    ),
                    const _RowDivider(),
                    // Language
                    _SettingRow(
                      icon: Icons.translate,
                      iconColor: scheme.primary,
                      label: l10n.languageLabel,
                      onTap: () => _pickLanguage(l10n),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _languageName(_language, l10n),
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Icon(
                            Icons.expand_more,
                            size: 20,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Daily goals ─────────────────────────────────────────────
                _GroupLabel(l10n.dailyGoalsLabel),
                const SizedBox(height: 8),
                _SettingsCard(
                  innerPadding: const EdgeInsets.all(14),
                  children: [
                    // Row 1: Calories + Protein
                    Row(
                      children: [
                        Expanded(
                          child: _GoalCell(
                            icon: Icons.local_fire_department,
                            iconColor: mc.calories,
                            label: l10n.caloriesLabel,
                            value: _formatInt(_calorieGoal),
                            onTap:
                                () => _openGoalSheet(
                                  label: l10n.caloriesLabel,
                                  suffix: 'kcal',
                                  initialText:
                                      _calorieGoal?.toString() ?? '',
                                  decimal: false,
                                  onSave:
                                      (text) => setState(
                                        () =>
                                            _calorieGoal =
                                                text.trim().isEmpty
                                                    ? null
                                                    : int.parse(text.trim()),
                                      ),
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _GoalCell(
                            icon: Icons.egg_alt,
                            iconColor: mc.protein,
                            label: l10n.proteinLabel,
                            value: _formatIntUnit(_proteinGoal, 'g'),
                            onTap:
                                () => _openGoalSheet(
                                  label: l10n.proteinLabel,
                                  suffix: 'g',
                                  initialText:
                                      _proteinGoal?.toString() ?? '',
                                  decimal: false,
                                  onSave:
                                      (text) => setState(
                                        () =>
                                            _proteinGoal =
                                                text.trim().isEmpty
                                                    ? null
                                                    : int.parse(text.trim()),
                                      ),
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Row 2: Carbs + Fat
                    Row(
                      children: [
                        Expanded(
                          child: _GoalCell(
                            icon: Icons.bakery_dining,
                            iconColor: mc.carbs,
                            label: l10n.carbsLabel,
                            value: _formatIntUnit(_carbsGoal, 'g'),
                            onTap:
                                () => _openGoalSheet(
                                  label: l10n.carbsLabel,
                                  suffix: 'g',
                                  initialText: _carbsGoal?.toString() ?? '',
                                  decimal: false,
                                  onSave:
                                      (text) => setState(
                                        () =>
                                            _carbsGoal =
                                                text.trim().isEmpty
                                                    ? null
                                                    : int.parse(text.trim()),
                                      ),
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _GoalCell(
                            icon: Icons.water_drop,
                            iconColor: mc.fat,
                            label: l10n.fatLabel,
                            value: _formatIntUnit(_fatGoal, 'g'),
                            onTap:
                                () => _openGoalSheet(
                                  label: l10n.fatLabel,
                                  suffix: 'g',
                                  initialText: _fatGoal?.toString() ?? '',
                                  decimal: false,
                                  onSave:
                                      (text) => setState(
                                        () =>
                                            _fatGoal =
                                                text.trim().isEmpty
                                                    ? null
                                                    : int.parse(text.trim()),
                                      ),
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Row 3: Water + placeholder (steps goal — TODO #19)
                    Row(
                      children: [
                        Expanded(
                          child: _GoalCell(
                            icon: Icons.water_drop_outlined,
                            iconColor: mc.water,
                            label: l10n.waterLabel,
                            value: _formatWater(_waterGoal),
                            onTap:
                                () => _openGoalSheet(
                                  label: l10n.waterLabel,
                                  suffix: 'L',
                                  initialText: _waterGoal?.toString() ?? '',
                                  decimal: true,
                                  onSave:
                                      (text) => setState(
                                        () =>
                                            _waterGoal =
                                                text.trim().isEmpty
                                                    ? null
                                                    : double.parse(
                                                      text
                                                          .replaceAll(',', '.')
                                                          .trim(),
                                                    ),
                                      ),
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _GoalCell(
                            icon: Icons.directions_walk,
                            iconColor: mc.steps,
                            label: l10n.stepsLabel,
                            value: _formatInt(_stepGoal),
                            onTap:
                                () => _openGoalSheet(
                                  label: l10n.stepsLabel,
                                  suffix: l10n.statUnitSteps,
                                  initialText: _stepGoal?.toString() ?? '',
                                  decimal: false,
                                  onSave:
                                      (text) => setState(
                                        () =>
                                            _stepGoal =
                                                text.trim().isEmpty
                                                    ? null
                                                    : int.parse(text.trim()),
                                      ),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Integrations ─────────────────────────────────────────────
                _GroupLabel(l10n.integrationsLabel),
                const SizedBox(height: 8),
                _SettingsCard(
                  children: [
                    // Water sources
                    _SettingRow(
                      icon: Icons.water_drop,
                      iconColor: mc.water,
                      label: l10n.manageWaterSourcesButton,
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WaterSourcesScreen(),
                            ),
                          ),
                      trailing: Icon(
                        Icons.chevron_right,
                        size: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    // Apple Health (iOS only)
                    if (Platform.isIOS) ...[
                      const _RowDivider(),
                      const _AppleHealthRow(),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // ── Account ────────────────────────────────────────────────
                _GroupLabel(l10n.accountLabel),
                const SizedBox(height: 8),
                _SettingsCard(
                  children: [
                    if (email != null) ...[
                      _SettingRow(
                        icon: Icons.email_outlined,
                        iconColor: scheme.primary,
                        label: l10n.emailLabel,
                        trailing: Text(
                          email,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const _RowDivider(),
                    ],
                    _SettingRow(
                      icon: Icons.lock_outline,
                      iconColor: scheme.primary,
                      label: l10n.changePasswordButton,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        size: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const _RowDivider(),
                    _SettingRow(
                      icon: Icons.accessibility_new,
                      iconColor: scheme.primary,
                      label: l10n.onboardingProfileTileLabel,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OnboardingEditScreen()),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        size: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Floating top bar ─────────────────────────────────────────────
          Positioned(
            top: barTop,
            left: 12,
            right: 12,
            child: AdaptiveAppBar(
              title: l10n.settingsTitle,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _languageName(LanguagePreference pref, AppLocalizations l10n) {
    return switch (pref) {
      LanguagePreference.system => l10n.optionSystem,
      LanguagePreference.english => l10n.languageEnglish,
      LanguagePreference.hungarian => l10n.languageHungarian,
    };
  }

  String _formatInt(int? value) {
    if (value == null) return '—';
    return NumberFormat.decimalPattern().format(value);
  }

  String _formatIntUnit(int? value, String unit) {
    if (value == null) return '—';
    return '${NumberFormat.decimalPattern().format(value)} $unit';
  }

  String _formatWater(double? value) {
    if (value == null) return '—';
    final s = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
    return '$s L';
  }
}

// ---------------------------------------------------------------------------
// _GroupLabel
// ---------------------------------------------------------------------------

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 0),
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

// ---------------------------------------------------------------------------
// _SettingsCard
// ---------------------------------------------------------------------------

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.children,
    this.innerPadding,
  });

  final List<Widget> children;
  // When non-null, overrides the default row-based padding with a flat padding.
  final EdgeInsets? innerPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Material ensures InkWell ripples render against the card color,
    // not the Scaffold background — which would look jarring on dark surfaces.
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: innerPadding ?? const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RowDivider
// ---------------------------------------------------------------------------

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      indent: 14,
      endIndent: 14,
      color: scheme.surfaceContainerHighest,
    );
  }
}

// ---------------------------------------------------------------------------
// _SettingRow
// ---------------------------------------------------------------------------

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.trailing,
    this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget trailing;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? scheme.primary;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: effectiveIconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card - 4),
        child: row,
      );
    }
    return row;
  }
}

// ---------------------------------------------------------------------------
// _InlinePillSegment<T>
// ---------------------------------------------------------------------------

class _InlinePillSegment<T> extends StatelessWidget {
  const _InlinePillSegment({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.pill,
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label) in options)
            GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: AppDuration.fast,
                curve: AppCurve.standard,
                decoration: BoxDecoration(
                  color:
                      value == selected
                          ? scheme.primary
                          : Colors.transparent,
                  borderRadius: AppRadius.pill,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    fontWeight:
                        value == selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                    color:
                        value == selected
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _GoalCell
// ---------------------------------------------------------------------------

class _GoalCell extends StatelessWidget {
  const _GoalCell({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _GoalEditSheet
// ---------------------------------------------------------------------------

class _GoalEditSheet extends StatefulWidget {
  const _GoalEditSheet({
    required this.label,
    required this.suffix,
    required this.initialText,
    required this.decimal,
    required this.onSave,
  });

  final String label;
  final String suffix;
  final String initialText;
  final bool decimal;
  final void Function(String text) onSave;

  @override
  State<_GoalEditSheet> createState() => _GoalEditSheetState();
}

class _GoalEditSheetState extends State<_GoalEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    // Read viewInsets inside the sheet's own build context so the dependency
    // is properly registered and cleaned up when this widget is disposed.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    // Capture validation strings at build time — avoids context lookups
    // inside the validator closure (which could run after disposal).
    final intError = l10n.enterNonNegativeWholeNumber;
    final decimalError = l10n.enterNonNegativeNumber;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType:
                  widget.decimal
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
              decoration: InputDecoration(
                suffixText: widget.suffix,
                hintText: l10n.leaveBlankForNoGoal,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  borderSide: BorderSide(color: scheme.primary, width: 2),
                ),
              ),
              validator: (value) {
                final text = (value ?? '').replaceAll(',', '.').trim();
                if (text.isEmpty) return null;
                final parsed =
                    widget.decimal
                        ? double.tryParse(text)
                        : int.tryParse(text);
                if (parsed == null || parsed < 0) {
                  return widget.decimal ? decimalError : intError;
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onSave(
                    _controller.text.replaceAll(',', '.').trim(),
                  );
                  Navigator.of(context).pop();
                }
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
              ),
              child: Text(l10n.saveButton),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AppleHealthRow
// ---------------------------------------------------------------------------

class _AppleHealthRow extends StatelessWidget {
  const _AppleHealthRow();

  static const Color _heartColor = Color(0xFFC46A6A);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.favorite, size: 22, color: _heartColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.appleHealthLabel,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          const _AppleHealthSwitch(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AppleHealthSwitch (iOS only)
// ---------------------------------------------------------------------------

class _AppleHealthSwitch extends ConsumerWidget {
  const _AppleHealthSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appleHealthControllerProvider);
    final enabled = state.value ?? false;
    return Switch(
      value: enabled,
      onChanged:
          state.isLoading
              ? null
              : (v) =>
                  ref
                      .read(appleHealthControllerProvider.notifier)
                      .setEnabled(v),
      activeThumbColor: Theme.of(context).colorScheme.primary,
      activeTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
    );
  }
}
