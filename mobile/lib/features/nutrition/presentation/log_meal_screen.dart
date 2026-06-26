import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../application/meal_controller.dart';
import '../data/meal_repository.dart';
import '../domain/food.dart';
import '../domain/meal.dart';
import 'widgets/add_macros_sheet.dart';
import 'widgets/add_meal_entry_sheet.dart';

/// Full-screen form for logging a meal, or editing one when [meal] is provided.
class LogMealScreen extends ConsumerStatefulWidget {
  const LogMealScreen({super.key, this.meal});

  final Meal? meal;

  @override
  ConsumerState<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends ConsumerState<LogMealScreen> {
  static final _dateTimeLabel = DateFormat('EEE, MMM d · HH:mm');

  late MealType _mealType;
  late DateTime _dateTime;
  final List<({Food food, double grams})> _entries = [];
  bool _saving = false;
  bool _pendingSave = false;
  String? _mealClientId;

  bool get _isEditing => widget.meal != null;

  double get _totalCalories =>
      _entries.fold(0, (s, e) => s + e.food.caloriesPer100g * e.grams / 100);
  double get _totalProtein =>
      _entries.fold(0, (s, e) => s + e.food.proteinPer100g * e.grams / 100);
  double get _totalCarbs =>
      _entries.fold(0, (s, e) => s + (e.food.carbsPer100g ?? 0) * e.grams / 100);
  double get _totalFat =>
      _entries.fold(0, (s, e) => s + (e.food.fatPer100g ?? 0) * e.grams / 100);

  bool get _hasMacroData => _entries.any((e) => e.food.caloriesPer100g > 0);

  static MealType _mealTypeForHour(int hour) {
    if (hour >= 5 && hour < 11) return MealType.breakfast;
    if (hour >= 11 && hour < 15) return MealType.lunch;
    if (hour >= 17 && hour < 22) return MealType.dinner;
    return MealType.snack;
  }

  @override
  void initState() {
    super.initState();
    final meal = widget.meal;
    _mealType = meal?.mealType ?? _mealTypeForHour(DateTime.now().hour);
    _dateTime = meal?.dateTime ?? DateTime.now();
    if (meal != null) {
      for (final entry in meal.entries) {
        final q = entry.quantityInGrams;
        _entries.add((
          food: Food(
            clientId: entry.foodClientId,
            name: entry.foodName,
            caloriesPer100g: q > 0 ? entry.calories / q * 100 : 0,
            proteinPer100g: q > 0 ? entry.protein / q * 100 : 0,
            carbsPer100g: q > 0 ? entry.carbs / q * 100 : 0,
            fatPer100g: q > 0 ? entry.fat / q * 100 : 0,
          ),
          grams: q,
        ));
      }
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (!mounted) return;
    final picked = DateTime(
      date.year, date.month, date.day,
      time?.hour ?? _dateTime.hour,
      time?.minute ?? _dateTime.minute,
    );
    setState(() => _dateTime = picked.isAfter(now) ? now : picked);
    _autoSave();
  }

  Future<void> _addEntry() async {
    final draft = await showModalBottomSheet<MealEntryDraft>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddMealEntrySheet(),
    );
    if (draft != null) {
      setState(() => _entries.add((food: draft.food, grams: draft.grams)));
      _autoSave();
    }
  }

  Future<void> _addMacros() async {
    final draft = await showModalBottomSheet<MealEntryDraft>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddMacrosSheet(),
    );
    if (draft != null) {
      setState(() => _entries.add((food: draft.food, grams: draft.grams)));
      _autoSave();
    }
  }

  Future<void> _editEntry(int index) async {
    final current = _entries[index];
    final draft = await showModalBottomSheet<MealEntryDraft>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddMealEntrySheet(
        initialFood: current.food,
        initialGrams: current.grams,
      ),
    );
    if (draft != null) {
      setState(() => _entries[index] = (food: draft.food, grams: draft.grams));
      _autoSave();
    }
  }

  void _removeEntry(int index) {
    setState(() => _entries.removeAt(index));
    _autoSave();
  }

  Future<void> _autoSave() async {
    if (_entries.isEmpty) return;
    if (_saving) {
      _pendingSave = true;
      return;
    }
    _pendingSave = false;
    setState(() => _saving = true);
    try {
      await _persist();
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: AppLocalizations.of(context)!.couldNotSaveMealMessage,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        if (_pendingSave) Future.microtask(_autoSave);
      }
    }
  }

  Future<void> _persist() async {
    final notifier = ref.read(mealControllerProvider.notifier);
    final entries = _entries
        .map((e) => MealEntryInput(foodClientId: e.food.clientId, grams: e.grams))
        .toList();
    final id = _isEditing ? widget.meal!.clientId : _mealClientId;
    if (id != null) {
      await notifier.updateMeal(id,
          dateTime: _dateTime,
          mealType: _mealType,
          entries: entries,
          name: widget.meal?.name);
    } else {
      _mealClientId = await notifier.logMeal(
          dateTime: _dateTime, mealType: _mealType, entries: entries);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusTop = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;
    final mc = context.metricColors;

    return Scaffold(
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────────────────
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              statusTop + 8 + 58 + 12, // clear the floating header
              16,
              bottomPad + 24,
            ),
            children: [
              // ── Section: Meal type ──────────────────────────────────────
              _SectionLabel(label: l10n.mealTypeLabel),
              const SizedBox(height: 8),
              _MealTypeRow(
                selected: _mealType,
                onChanged: (t) {
                  setState(() => _mealType = t);
                  _autoSave();
                },
                l10n: l10n,
              ),

              const SizedBox(height: 20),

              // ── Section: When ───────────────────────────────────────────
              _SectionLabel(label: l10n.whenLabel),
              const SizedBox(height: 8),
              _WhenTile(
                dateTime: _dateTime,
                label: _dateTimeLabel.format(_dateTime.toLocal()),
                onTap: _pickDateTime,
              ),

              const SizedBox(height: 20),

              // ── Section: Foods ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionLabel(label: l10n.foodsLabel),
                  Row(
                    children: [
                      _SectionActionButton(
                        label: l10n.addMacrosButton,
                        icon: Icons.speed,
                        color: scheme.tertiary,
                        onTap: _addMacros,
                      ),
                      const SizedBox(width: 12),
                      _SectionActionButton(
                        label: l10n.addFoodButton,
                        icon: Icons.add,
                        color: scheme.primary,
                        onTap: _addEntry,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Food entries
              ..._entries.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _FoodEntryCard(
                      food: e.value.food,
                      grams: e.value.grams,
                      onTap: () => _editEntry(e.key),
                      onRemove: () => _removeEntry(e.key),
                    ),
                  )),

              // Dashed "add another food" placeholder
              _AddAnotherFoodButton(
                label: l10n.addFoodButton,
                onTap: _addEntry,
              ),

              // ── Meal total ──────────────────────────────────────────────
              if (_hasMacroData) ...[
                const SizedBox(height: 12),
                _MealTotalCard(
                  label: l10n.mealTotalLabel,
                  calories: _totalCalories,
                  protein: _totalProtein,
                  carbs: _totalCarbs,
                  fat: _totalFat,
                  proteinLabel: l10n.proteinLabel,
                  carbsLabel: l10n.carbsLabel,
                  fatLabel: l10n.fatLabel,
                  mc: mc,
                ),
              ],
            ],
          ),

          // ── Floating header ─────────────────────────────────────────────
          Positioned(
            top: statusTop + 8,
            left: 12,
            right: 12,
            child: _DetailBar(
              title: _isEditing ? l10n.editMealTitle : l10n.logMealTitle,
              onBack: () => Navigator.of(context).pop(),
              saving: _saving,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating detail header — frosted pill, no collapse
// ---------------------------------------------------------------------------

class _DetailBar extends StatelessWidget {
  const _DetailBar({
    required this.title,
    required this.onBack,
    required this.saving,
  });

  final String title;
  final VoidCallback onBack;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: scheme.surfaceContainer.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.arrow_back,
                      size: 21,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Title
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              // Auto-save indicator
              if (saving)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                )
              else
                const SizedBox(width: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meal type selector row
// ---------------------------------------------------------------------------

class _MealTypeRow extends StatelessWidget {
  const _MealTypeRow({
    required this.selected,
    required this.onChanged,
    required this.l10n,
  });

  final MealType selected;
  final ValueChanged<MealType> onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (int i = 0; i < MealType.values.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _MealTypeButton(
              type: MealType.values[i],
              selected: selected == MealType.values[i],
              label: MealType.values[i].label(l10n),
              onTap: () => onChanged(MealType.values[i]),
              scheme: scheme,
            ),
          ),
        ],
      ],
    );
  }
}

class _MealTypeButton extends StatelessWidget {
  const _MealTypeButton({
    required this.type,
    required this.selected,
    required this.label,
    required this.onTap,
    required this.scheme,
  });

  final MealType type;
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? scheme.secondary : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 15, color: scheme.onSecondary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? scheme.onSecondary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// When tile
// ---------------------------------------------------------------------------

class _WhenTile extends StatelessWidget {
  const _WhenTile({
    required this.dateTime,
    required this.label,
    required this.onTap,
  });

  final DateTime dateTime;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 21, color: scheme.primary),
            const SizedBox(width: 9),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Food entry card
// ---------------------------------------------------------------------------

class _FoodEntryCard extends StatelessWidget {
  const _FoodEntryCard({
    required this.food,
    required this.grams,
    required this.onTap,
    required this.onRemove,
  });

  final Food food;
  final double grams;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  String _kcalLabel() {
    if (food.caloriesPer100g <= 0) return '${grams.toStringAsFixed(0)} g';
    final kcal = (food.caloriesPer100g * grams / 100).round();
    return '${grams.toStringAsFixed(0)} g · $kcal kcal';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final mc = context.metricColors;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Icon(Icons.restaurant, size: 22, color: mc.carbs),
              ),
            ),
            const SizedBox(width: 13),
            // Name + quantity
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _kcalLabel(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Remove button
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Icon(Icons.close, size: 19, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "Add another food" dashed placeholder
// ---------------------------------------------------------------------------

class _AddAnotherFoodButton extends StatelessWidget {
  const _AddAnotherFoodButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: scheme.outline.withValues(alpha: 0.5),
          radius: 18,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 21, color: scheme.onSurfaceVariant),
              const SizedBox(width: 7),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashLen = 6.0;
    const gapLen = 4.0;
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rr);
    final metrics = path.computeMetrics().first;
    double dist = 0;
    while (dist < metrics.length) {
      final end = math.min(dist + dashLen, metrics.length);
      canvas.drawPath(metrics.extractPath(dist, end), paint);
      dist += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

// ---------------------------------------------------------------------------
// Meal total card
// ---------------------------------------------------------------------------

class _MealTotalCard extends StatelessWidget {
  const _MealTotalCard({
    required this.label,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.proteinLabel,
    required this.carbsLabel,
    required this.fatLabel,
    required this.mc,
  });

  final String label;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String proteinLabel;
  final String carbsLabel;
  final String fatLabel;
  final AppMetricColors mc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          // Calorie total row
          Row(
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(Icons.local_fire_department, size: 18, color: mc.calories),
              const SizedBox(width: 5),
              Text(
                calories.round().toString(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 3),
              Text(
                'kcal',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Macro pills
          Row(
            children: [
              Expanded(
                child: _MacroMiniPill(
                  value: protein,
                  label: proteinLabel,
                  color: mc.protein,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroMiniPill(
                  value: carbs,
                  label: carbsLabel,
                  color: mc.carbs,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroMiniPill(
                  value: fat,
                  label: fatLabel,
                  color: mc.fat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroMiniPill extends StatelessWidget {
  const _MacroMiniPill({
    required this.value,
    required this.label,
    required this.color,
  });

  final double value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(
            '${value.round()} g',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section action button (small icon + label, used in header rows)
// ---------------------------------------------------------------------------

class _SectionActionButton extends StatelessWidget {
  const _SectionActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
