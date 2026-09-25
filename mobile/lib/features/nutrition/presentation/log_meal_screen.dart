import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/ads/interstitial_manager.dart';
import '../../../core/entitlements/ai_credit_gate.dart';
import '../../../core/entitlements/paywall_navigation.dart';
import '../../../core/entitlements/paywall_trigger.dart';
import '../../../core/network/error_message.dart';
import '../../../core/sync/connectivity_status_provider.dart';
import '../../../core/format/lifey_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/ds/lifey_card.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/ds/section_label.dart';
import '../../settings/application/settings_controller.dart';
import '../application/meal_controller.dart';
import '../application/meal_estimation_controller.dart';
import '../application/selected_meal_day_provider.dart';
import '../data/meal_repository.dart';
import '../domain/food.dart';
import '../domain/meal.dart';
import '../domain/meal_budget_preview.dart';
import '../domain/meal_days.dart';
import 'widgets/add_macros_sheet.dart';
import 'widgets/add_meal_entry_sheet.dart';
import 'widgets/ai_credit_chip.dart';
import 'widgets/meal_estimate_sheet.dart';
import 'widgets/meal_summary_panel.dart';

/// Full-screen form for logging a meal, or editing one when [meal] is provided.
///
/// Pass [initialFood] to start a new meal with the add-food sheet already
/// open on that food (docs/75-log-food-from-foods-tab-plan.md §2.4); if that
/// first sheet is dismissed without adding anything, the screen closes too.
class LogMealScreen extends ConsumerStatefulWidget {
  const LogMealScreen({
    super.key,
    this.meal,
    this.initialFood,
    this.startWithPhoto = false,
    this.initialDate,
  })  : assert(meal == null || initialFood == null),
        assert(!startWithPhoto || (meal == null && initialFood == null)),
        assert(initialDate == null || meal == null);

  final Meal? meal;
  final Food? initialFood;

  /// The day a new meal is logged on (the Meals tab's selected day), at the
  /// current time of day. Null = now.
  final DateTime? initialDate;

  /// Open straight into "estimate from a photo" (the dashboard's Photo
  /// action). The screen closes again if nothing came of it — cancelled,
  /// offline or a failed pick — so it never strands the user on an empty
  /// meal.
  final bool startWithPhoto;

  @override
  ConsumerState<LogMealScreen> createState() => _LogMealScreenState();
}

/// How an AI photo estimate ended — see [LogMealScreen.startWithPhoto].
enum _PhotoOutcome { added, dismissed, paywall }

class _LogMealScreenState extends ConsumerState<LogMealScreen> {
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
  double get _totalCarbs => _entries.fold(
      0, (s, e) => s + (e.food.carbsPer100g ?? 0) * e.grams / 100);
  double get _totalFat =>
      _entries.fold(0, (s, e) => s + (e.food.fatPer100g ?? 0) * e.grams / 100);

  bool get _hasMacroData => _entries.any((e) => e.food.caloriesPer100g > 0);

  bool get _isToday => DateUtils.isSameDay(_dateTime, DateTime.now());

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
    final now = DateTime.now();
    final day = widget.initialDate;
    _dateTime = meal?.dateTime ??
        (day == null
            ? now
            : DateTime(day.year, day.month, day.day, now.hour, now.minute));
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
    final initialFood = widget.initialFood;
    if (initialFood != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _addEntry(preselected: initialFood, closeScreenOnCancel: true);
        }
      });
    }
    if (widget.startWithPhoto) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final outcome = await _estimateFromPhoto();
        // A paywall route is on top in the `paywall` case: popping would
        // close that instead of this screen.
        if (mounted && outcome == _PhotoOutcome.dismissed && _entries.isEmpty) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (!mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? _dateTime.hour,
      time?.minute ?? _dateTime.minute,
    );
    setState(() => _dateTime = picked);
    _autoSave();
  }

  /// [closeScreenOnCancel] is only set for the sheet auto-opened from
  /// [LogMealScreen.initialFood]: dismissing it on a still-empty meal leaves
  /// the screen too (docs/75 §2.5). Nothing needs undoing — an empty meal is
  /// never persisted.
  Future<void> _addEntry(
      {Food? preselected, bool closeScreenOnCancel = false}) async {
    final draft = await showModalBottomSheet<MealEntryDraft>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddMealEntrySheet(
        preselectedFood: preselected,
        mealDateTime: _dateTime,
      ),
    );
    if (!mounted) return;
    if (draft != null) {
      setState(() => _entries.add((food: draft.food, grams: draft.grams)));
      _autoSave();
    } else if (closeScreenOnCancel && _entries.isEmpty) {
      Navigator.of(context).pop();
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

  /// AI estimate from a meal photo (docs/23-ai-calorie-estimation-plan.md).
  /// The estimate needs the network; the confirmed items are saved like any
  /// other entry. The credit check here is a courtesy — the server's 402 is
  /// authoritative, and lands on the same paywall.
  Future<_PhotoOutcome> _estimateFromPhoto() async {
    final l10n = AppLocalizations.of(context)!;
    if (ref.read(isOfflineProvider).value ?? false) {
      AppSnackbar.showError(context, title: l10n.mealEstimateOfflineMessage);
      return _PhotoOutcome.dismissed;
    }
    if (!requireAiCredits(context, ref)) return _PhotoOutcome.paywall;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.takePhotoAction),
              onTap: () => Navigator.of(sheetCtx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGalleryAction),
              onTap: () => Navigator.of(sheetCtx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return _PhotoOutcome.dismissed;

    final XFile? picked;
    try {
      // Downscaled on the device too: the server bounds the photo to 1024 px
      // anyway, so anything larger is only upload time on mobile data.
      picked = await ImagePicker().pickImage(
          source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
      return _PhotoOutcome.dismissed;
    }
    if (picked == null || !mounted) return _PhotoOutcome.dismissed;
    final imagePath = picked.path;

    final drafts = await showModalBottomSheet<List<MealEntryDraft>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MealEstimateSheet(imagePath: imagePath),
    );
    if (!mounted) return _PhotoOutcome.dismissed;
    if (drafts != null && drafts.isNotEmpty) {
      setState(() =>
          _entries.addAll(drafts.map((d) => (food: d.food, grams: d.grams))));
      _autoSave();
      return _PhotoOutcome.added;
    } else if (ref.read(mealEstimationControllerProvider)
        is MealEstimationCreditsExhausted) {
      openPaywall(context, PaywallTrigger.aiCredits);
      return _PhotoOutcome.paywall;
    }
    return _PhotoOutcome.dismissed;
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
        mealDateTime: _dateTime,
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
        .map((e) =>
            MealEntryInput(foodClientId: e.food.clientId, grams: e.grams))
        .toList();
    final id = _isEditing ? widget.meal!.clientId : _mealClientId;
    if (id != null) {
      await notifier.updateMeal(id,
          dateTime: _dateTime,
          mealType: _mealType,
          entries: entries,
          name: widget.meal?.name);
    } else {
      final isFirstSave = _mealClientId == null;
      _mealClientId = await notifier.logMeal(
          dateTime: _dateTime, mealType: _mealType, entries: entries);
      // `67` §5.3: only the meal's creation counts as "successfully
      // logged" — the auto-save on every subsequent edit must not re-trigger
      // this (it isn't a new meal, and it would also blow past the
      // once-per-session limit on the very first screen that logs anything).
      if (isFirstSave && mounted) {
        unawaited(ref.read(interstitialManagerProvider).maybeShow(
              context,
              InterstitialReason.mealLogged,
            ));
      }
    }
  }

  /// "Save": the meal is autosaved on every change, so this finishes any save
  /// still in flight and closes the screen.
  Future<void> _saveAndClose() async {
    while (mounted && (_saving || _pendingSave)) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// The day's other meals + this draft against the calorie goal — null
  /// without a goal, or while the day's meals are still loading.
  MealBudgetPreview? _budgetPreview() {
    final goal = ref.watch(settingsControllerProvider).value?.dailyCalorieGoal;
    if (goal == null || goal <= 0) return null;
    final dayMeals =
        ref.watch(mealsOnDayProvider(dateOnly(_dateTime.toLocal()))).value;
    if (dayMeals == null) return null;
    return MealBudgetPreview(
      goal: goal,
      othersKcal: MealBudgetPreview.othersKcalOf(
        dayMeals,
        excludeClientId: _isEditing ? widget.meal!.clientId : _mealClientId,
      ),
      draftKcal: _totalCalories,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final offline = ref.watch(isOfflineProvider).value ?? false;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: LifeySubpageHeader(
        title: _isEditing ? l10n.editMealTitle : l10n.logMealTitle,
        actions: [
          FilledButton(
            onPressed: _saveAndClose,
            style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                tapTargetSize: MaterialTapTargetSize.padded),
            child: Text(l10n.saveButton),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8,
            AppSpacing.screen, AppSpacing.s24),
        children: [
          // Meal type — choice chips.
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (final type in MealType.values)
                ChoiceChip(
                  label: Text(type.label(l10n)),
                  selected: _mealType == type,
                  onSelected: (_) {
                    setState(() => _mealType = type);
                    _autoSave();
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          // When.
          LifeyCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            onTap: _pickDateTime,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 22, color: p.text2),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text(
                      '${f.shortDayLabel(_dateTime.toLocal())} · ${f.time(_dateTime.toLocal())}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium!
                          .copyWith(fontSize: 16, color: p.text),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, size: 24, color: p.text2),
                ],
              ),
            ),
          ),
          if (_entries.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s16),
            SectionLabel(l10n.mealFoodsSectionCount(_entries.length)),
            const SizedBox(height: AppSpacing.s8),
            ListGroup(
              dividerInset: AppSpacing.s16,
              children: [
                for (final (i, entry) in _entries.indexed)
                  _FoodRow(
                    food: entry.food,
                    grams: entry.grams,
                    onTap: () => _editEntry(i),
                    onRemove: () => _removeEntry(i),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.s16),
          // Three equal actions.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.add_rounded,
                    label: l10n.addFoodButton,
                    background: p.primaryTint,
                    foreground: primary,
                    onTap: _addEntry,
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.tune_rounded,
                    label: l10n.mealActionMacrosOnly,
                    background: p.nested,
                    foreground: p.text,
                    onTap: _addMacros,
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.photo_camera_outlined,
                    label: l10n.mealActionFromPhoto,
                    // Dimmed, not disabled: tapping it offline explains why it
                    // can't run.
                    background: p.nested,
                    foreground: offline ? p.text2 : p.text,
                    onTap: _estimateFromPhoto,
                    footer: const AiCreditChip(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Pinned above the keyboard and the bottom edge, outside the list.
      bottomNavigationBar: _hasMacroData || _entries.isNotEmpty
          ? Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s8,
                  AppSpacing.s12, math.max(bottomInset, AppSpacing.s12)),
              child: MealSummaryPanel(
                calories: _totalCalories,
                protein: _totalProtein,
                carbs: _totalCarbs,
                fat: _totalFat,
                preview: _budgetPreview(),
                day: _isToday ? null : _dateTime.toLocal(),
              ),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Food row — name, "60 g · 8 g protein", kcal and the ⋮ menu
// ---------------------------------------------------------------------------

enum _FoodAction { edit, remove }

class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.food,
    required this.grams,
    required this.onTap,
    required this.onRemove,
  });

  final Food food;
  final double grams;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final hasMacros = food.caloriesPer100g > 0;
    final kcal = food.caloriesPer100g * grams / 100;
    final protein = food.proteinPer100g * grams / 100;
    final subtitle = hasMacros
        ? l10n.mealFoodRowSubtitle(f.grams(grams), f.grams(protein))
        : '${f.grams(grams)} g';

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.only(
              left: AppSpacing.s16, top: AppSpacing.s8, bottom: AppSpacing.s8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(food.name,
                        style: t.titleMedium!.copyWith(
                            fontSize: 16, height: 1.25, color: p.text)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: t.bodySmall!.copyWith(
                            fontSize: 13, height: 1.4, color: p.text2)),
                  ],
                ),
              ),
              if (hasMacros) ...[
                const SizedBox(width: AppSpacing.s8),
                ListRowValue(value: f.kcal(kcal), unit: 'kcal', size: 16),
              ],
              PopupMenuButton<_FoodAction>(
                tooltip: l10n.mealFoodMenuTooltip,
                icon: Icon(Icons.more_vert_rounded, color: p.text2),
                onSelected: (a) => switch (a) {
                  _FoodAction.edit => onTap(),
                  _FoodAction.remove => onRemove(),
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: _FoodAction.edit, child: Text(l10n.editMenuItem)),
                  PopupMenuItem(
                    value: _FoodAction.remove,
                    child: Text(l10n.removeButton,
                        style: TextStyle(color: context.metricColors.heart)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action tile — "Add food" / "Macros only" / "From photo"
// ---------------------------------------------------------------------------

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.footer,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  /// Under the label — the AI credit chip on "From photo".
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.control);
    return Material(
      color: background,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4, vertical: AppSpacing.s12),
            // Three tiles share the row, so their labels stop growing at 115 %
            // (a wrapped "hozzáadása" would break mid-word).
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.15,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24, color: foreground),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: foreground),
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: AppSpacing.s4),
                    footer!
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
