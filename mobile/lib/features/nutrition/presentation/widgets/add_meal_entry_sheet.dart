import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../core/utils/search_normalize.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../settings/application/settings_controller.dart';
import '../../application/food_controller.dart';
import '../../application/food_usage_provider.dart';
import '../../application/selected_meal_day_provider.dart';
import '../../domain/food.dart';
import '../../domain/food_usage.dart';
import '../../domain/meal_days.dart';
import '../barcode_scanner_screen.dart';
import 'add_food_sheet.dart';

/// Result of picking a food + quantity for a meal entry.
typedef MealEntryDraft = ({Food food, double grams});

/// Bottom sheet to pick a food and set how much of it. Pops with a
/// [MealEntryDraft].
///
/// The canvas' "Add food" (docs/redesign/77-mobile-redesign-plan.md R2.6;
/// Lifey 2 › 2.2): a search field with the barcode scanner inside it, the
/// recent foods as chips, and — once a food is picked — its card with the
/// **quantity as the hero**: a big number between two 56 dp − / + buttons
/// (tap the number to type an exact amount), quick chips (100 g, 150 g, the
/// last amount used) and a live "+145 kcal → 1,594 kcal left" line.
///
/// Pass [initialFood] and [initialGrams] to open in edit mode — the food is
/// locked to the existing one, only the quantity is editable.
///
/// Pass [preselectedFood] to open in add mode with that food already picked
/// (docs/75-log-food-from-foods-tab-plan.md §2.2): unlike edit mode the food
/// stays changeable, but the quantity is focused and prefilled with the
/// food's last-used grams, and the recents row is hidden.
///
/// Pass [mealDateTime] so the sheet can show what this does to that day's
/// budget — only when a calorie goal is set.
class AddMealEntrySheet extends ConsumerStatefulWidget {
  const AddMealEntrySheet({
    super.key,
    this.initialFood,
    this.initialGrams,
    this.preselectedFood,
    this.mealDateTime,
  }) : assert(initialFood == null || preselectedFood == null);

  final Food? initialFood;
  final double? initialGrams;
  final Food? preselectedFood;
  final DateTime? mealDateTime;

  @override
  ConsumerState<AddMealEntrySheet> createState() => _AddMealEntrySheetState();
}

/// Cap on how many matching foods are shown at once, so the suggestion list
/// stays short even as the food catalog grows.
const _maxSuggestions = 20;

/// What the − and + buttons change the quantity by.
const _gramsStep = 10.0;

/// The fixed quick amounts next to the last-used one (canvas: 100 g, 150 g).
const _quickGrams = [100.0, 150.0];

class _AddMealEntrySheetState extends ConsumerState<AddMealEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _grams;
  final _gramsFocus = FocusNode();
  Food? _food;
  String? _foodError;

  /// The Autocomplete field's controller, captured from its
  /// `fieldViewBuilder` so recent-chip taps can write the food name into it.
  TextEditingController? _foodFieldController;

  /// True while the grams field holds a value we prefilled (the food's
  /// last-used quantity) rather than something the user typed — a later
  /// chip tap may overwrite a prefill, never a hand-entered value.
  bool _gramsAutoFilled = false;

  bool get _isEditing => widget.initialFood != null;

  bool get _isPreselected => widget.preselectedFood != null;

  /// Set once the pre-selected food's last-used grams have been applied, so
  /// later [foodUsageProvider] emissions don't prefill again (docs/75 §2.3).
  bool _preselectPrefillApplied = false;

  @override
  void initState() {
    super.initState();
    _food = widget.initialFood ?? widget.preselectedFood;
    final initial = widget.initialGrams?.toStringAsFixed(0) ?? '';
    _grams = TextEditingController(text: initial);
    if (_isPreselected) {
      // Usage may not have emitted yet when the sheet opens, so prefill on
      // the first emission that has stats for the food — outside build, and
      // never over grams the user already typed (see [_prefillGrams]).
      ref.listenManual<AsyncValue<Map<String, FoodUsage>>>(
        foodUsageProvider,
        (_, next) => _prefillPreselected(next.value),
        fireImmediately: true,
      );
    }
  }

  void _prefillPreselected(Map<String, FoodUsage>? usage) {
    if (_preselectPrefillApplied || usage == null) return;
    final food = widget.preselectedFood!;
    if (_food?.clientId != food.clientId) return;
    final stats = usage[food.clientId];
    if (stats == null) return;
    _preselectPrefillApplied = true;
    _prefillGrams(stats);
  }

  @override
  void dispose() {
    _grams.dispose();
    _gramsFocus.dispose();
    super.dispose();
  }

  void _prefillGrams(FoodUsage stats) {
    if (_grams.text.trim().isNotEmpty && !_gramsAutoFilled) return;
    final text = stats.lastGrams.toStringAsFixed(0);
    _grams.text = text;
    // Select the prefill so typing replaces it outright.
    _grams.selection = TextSelection(baseOffset: 0, extentOffset: text.length);
    _gramsAutoFilled = true;
  }

  void _pickRecent(Food food, FoodUsage stats) {
    _foodFieldController?.text = food.name;
    setState(() {
      _food = food;
      _foodError = null;
    });
    _prefillGrams(stats);
    _gramsFocus.requestFocus();
  }

  double? get _gramsValue => double.tryParse(_grams.text.replaceAll(',', '.'));

  /// Puts [grams] into the field as the user's own choice (a − / + press or a
  /// quick chip), so a later recent-chip tap never overwrites it.
  void _setGrams(double grams) {
    final value = grams < 1 ? 1.0 : grams;
    final text = value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    setState(() {
      _grams.text = text;
      _grams.selection = TextSelection.collapsed(offset: text.length);
      _gramsAutoFilled = false;
    });
  }

  void _nudge(double delta) => _setGrams((_gramsValue ?? 0) + delta);

  /// The scanner inside the search field: a food already in the catalogue
  /// with that barcode is picked right away; an unknown code goes through the
  /// same lookup / create sheet as the Nutrition header's scanner.
  Future<void> _scan(List<Food> foods, Map<String, FoodUsage> usage) async {
    final barcode = await Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || !mounted) return;
    final match = foods.where((f) => f.barcode == barcode).firstOrNull;
    if (match != null) {
      _foodFieldController?.text = match.name;
      setState(() {
        _food = match;
        _foodError = null;
      });
      final stats = usage[match.clientId];
      if (stats != null) _prefillGrams(stats);
      _gramsFocus.requestFocus();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddFoodSheet(initialBarcode: barcode),
    );
  }

  void _submit() {
    final formValid = _formKey.currentState!.validate();
    final foodPicked = _food != null;
    setState(() => _foodError = foodPicked ? null : AppLocalizations.of(context)!.pickAFoodError);
    if (!formValid || !foodPicked) return;
    final grams = double.parse(_grams.text.replaceAll(',', '.'));
    Navigator.of(context).pop<MealEntryDraft>((food: _food!, grams: grams));
  }

  @override
  Widget build(BuildContext context) {
    final foodsState = ref.watch(foodSearchProvider);
    final usage = ref.watch(foodUsageProvider).value ?? const <String, FoodUsage>{};
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final l10n = AppLocalizations.of(context)!;
    final t = Theme.of(context).textTheme;
    final p = context.palette;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s4, AppSpacing.screen, AppSpacing.s20 + viewInsets),
      child: foodsState.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('${l10n.couldNotLoadFoodsPrefix} $e'),
        ),
        data: (foods) {
          if (foods.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.addFoodsFirstMessage),
            );
          }
          final ranked = rankFoodsByUsage(foods, usage);
          // Hidden while the pre-selected food is still picked — the user
          // already chose; clearing it brings the row back.
          final hideRecents = _isEditing || (_isPreselected && _food?.clientId == widget.preselectedFood!.clientId);
          final recents = hideRecents ? const <Food>[] : recentFoodsByUsage(foods, usage);
          return Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          _isEditing ? l10n.editFoodEntryTitle : l10n.addFoodToMealTitle,
                          style: t.headlineSmall!.copyWith(height: 1.2, color: p.text),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: p.text2),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                if (!_isEditing)
                  LayoutBuilder(
                    builder: (context, constraints) => Autocomplete<Food>(
                      displayStringForOption: (f) => f.name,
                      initialValue: _isPreselected ? TextEditingValue(text: widget.preselectedFood!.name) : null,
                      optionsBuilder: (textEditingValue) {
                        final query = normalizeForSearch(textEditingValue.text.trim());
                        // Nothing until the user types: the recent chips are
                        // the empty-field shortcut, and an open list would sit
                        // on top of them (and on the picked food's card).
                        if (query.isEmpty) return const Iterable<Food>.empty();
                        return ranked.where((f) => normalizeForSearch(f.name).contains(query)).take(_maxSuggestions);
                      },
                      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                        _foodFieldController = controller;
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          autofocus: !_isPreselected,
                          decoration: InputDecoration(
                            hintText: l10n.searchFoodsHint,
                            errorText: _foodError,
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _food == null
                                ? IconButton(
                                    tooltip: l10n.scanBarcodeButton,
                                    icon: const Icon(Icons.qr_code_scanner_rounded),
                                    onPressed: () => _scan(foods, usage),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      controller.clear();
                                      setState(() => _food = null);
                                    },
                                  ),
                          ),
                          onChanged: (_) {
                            if (_food != null) setState(() => _food = null);
                          },
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) => _FoodOptions(
                        options: options.toList(),
                        width: constraints.maxWidth,
                        onSelected: onSelected,
                      ),
                      onSelected: (food) {
                        setState(() {
                          _food = food;
                          _foodError = null;
                        });
                        final stats = usage[food.clientId];
                        if (stats != null) _prefillGrams(stats);
                        _gramsFocus.requestFocus();
                      },
                    ),
                  ),
                if (recents.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s12),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recents.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s8),
                      itemBuilder: (context, i) => ActionChip(
                        label: Text(recents[i].name),
                        onPressed: () => _pickRecent(recents[i], usage[recents[i].clientId]!),
                      ),
                    ),
                  ),
                ],
                if (_food != null) ...[
                  const SizedBox(height: AppSpacing.s16),
                  _SelectedFoodCard(
                    food: _food!,
                    grams: _grams,
                    gramsFocus: _gramsFocus,
                    lastGrams: usage[_food!.clientId]?.lastGrams,
                    autofocus: _isEditing || _isPreselected,
                    mealDateTime: widget.mealDateTime,
                    replacedKcal: widget.initialFood == null
                        ? 0
                        : widget.initialFood!.caloriesPer100g * (widget.initialGrams ?? 0) / 100,
                    onNudge: _nudge,
                    onSetGrams: _setGrams,
                    onTyped: () => _gramsAutoFilled = false,
                    onSubmit: _submit,
                  ),
                ],
                const SizedBox(height: AppSpacing.s16),
                FilledButton.icon(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  icon: _isEditing ? null : const Icon(Icons.add_rounded),
                  label: Text(_isEditing ? l10n.saveButton : l10n.addToMealButton),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The autocomplete's suggestion list: a card of name + kcal per 100 g rows,
/// as wide as the search field.
class _FoodOptions extends StatelessWidget {
  const _FoodOptions({required this.options, required this.width, required this.onSelected});

  final List<Food> options;
  final double width;
  final ValueChanged<Food> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = LifeyFormat.of(context);
    final t = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s4),
        child: Material(
          color: p.nested,
          elevation: 4,
          shadowColor: Colors.black,
          borderRadius: BorderRadius.circular(AppRadius.control),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 240, maxWidth: width, minWidth: width),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, i) {
                final food = options[i];
                return InkWell(
                  onTap: () => onSelected(food),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(food.name, style: t.bodyMedium!.copyWith(fontWeight: FontWeight.w700, color: p.text)),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Text(
                            '${f.kcal(food.caloriesPer100g)} kcal',
                            style: t.bodySmall!.copyWith(color: p.text2),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The picked food: name, "per 100 g · 89 kcal", the quantity stepper with
/// its quick chips, and the live effect on the day's budget.
class _SelectedFoodCard extends ConsumerWidget {
  const _SelectedFoodCard({
    required this.food,
    required this.grams,
    required this.gramsFocus,
    required this.lastGrams,
    required this.autofocus,
    required this.mealDateTime,
    required this.replacedKcal,
    required this.onNudge,
    required this.onSetGrams,
    required this.onTyped,
    required this.onSubmit,
  });

  final Food food;
  final TextEditingController grams;
  final FocusNode gramsFocus;
  final double? lastGrams;
  final bool autofocus;
  final DateTime? mealDateTime;

  /// kcal of the entry being edited, already inside the day's saved total.
  final double replacedKcal;
  final ValueChanged<double> onNudge;
  final ValueChanged<double> onSetGrams;
  final VoidCallback onTyped;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final mc = context.metricColors;
    final t = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;

    final quick = <double>{..._quickGrams, if (lastGrams != null) lastGrams!}.toList()..sort();

    const decoration = InputDecoration(
      isDense: true,
      filled: false,
      constraints: BoxConstraints(),
      contentPadding: EdgeInsets.zero,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: primary, width: 1.5),
      ),
      child: LifeyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(food.name, style: t.titleLarge!.copyWith(color: p.text)),
            const SizedBox(height: 2),
            Text(
              food.caloriesPer100g > 0
                  ? l10n.entryFoodPer100(f.kcal(food.caloriesPer100g))
                  : l10n.entryFoodPer100NoKcal,
              style: t.titleSmall!.copyWith(fontWeight: FontWeight.w500, color: p.text2),
            ),
            const SizedBox(height: AppSpacing.s16),
            Row(
              children: [
                _StepButton(
                  icon: Icons.remove_rounded,
                  tooltip: l10n.quantityDecreaseTooltip,
                  onPressed: () => onNudge(-_gramsStep),
                ),
                Expanded(
                  child: Semantics(
                    label: l10n.quantityLabel,
                    // The number and its unit sit together in the middle:
                    // IntrinsicWidth makes the field as wide as its digits.
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: IntrinsicWidth(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 48),
                              child: TextFormField(
                                key: const Key('quantityField'),
                                controller: grams,
                                focusNode: gramsFocus,
                                autofocus: autofocus,
                                textAlign: TextAlign.center,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                                textInputAction: TextInputAction.done,
                                style: AppType.number(44, weight: FontWeight.w800, color: p.text),
                                decoration: decoration,
                                onChanged: (_) => onTyped(),
                                validator: (v) {
                                  final parsed = double.tryParse((v ?? '').replaceAll(',', '.'));
                                  if (parsed == null) return l10n.enterANumberError;
                                  if (parsed <= 0) return l10n.mustBeGreaterThanZeroError;
                                  return null;
                                },
                                onFieldSubmitted: (_) => onSubmit(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Text(
                          'g',
                          style: t.titleLarge!.copyWith(fontWeight: FontWeight.w700, color: p.text2),
                        ),
                      ],
                    ),
                  ),
                ),
                _StepButton(
                  icon: Icons.add_rounded,
                  tooltip: l10n.quantityIncreaseTooltip,
                  onPressed: () => onNudge(_gramsStep),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: grams,
              builder: (context, _, __) {
                final current = double.tryParse(grams.text.replaceAll(',', '.'));
                return Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    for (final amount in quick)
                      ChoiceChip(
                        label: Text('${f.grams(amount)} g'),
                        selected: current == amount,
                        showCheckmark: false,
                        onSelected: (_) => onSetGrams(amount),
                      ),
                  ],
                );
              },
            ),
            if (food.caloriesPer100g > 0) ...[
              const SizedBox(height: AppSpacing.s12),
              Divider(height: 1, thickness: 1, color: p.hairline),
              const SizedBox(height: AppSpacing.s12),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: grams,
                builder: (context, _, __) {
                  final amount = double.tryParse(grams.text.replaceAll(',', '.'));
                  if (amount == null || amount <= 0) return const SizedBox(height: 40);
                  final kcal = food.caloriesPer100g * amount / 100;
                  final protein = food.proteinPer100g * amount / 100;
                  final remaining = _remainingAfter(ref, kcal - replacedKcal);
                  return Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s4,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.entryPreviewKcal(f.kcal(kcal)),
                            style: t.headlineSmall!.copyWith(fontWeight: FontWeight.w800, color: mc.calories, fontFeatures: AppType.tabular),
                          ),
                          Text(
                            l10n.entryPreviewProtein(f.grams(protein)),
                            style: t.bodySmall!.copyWith(color: mc.protein, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      if (remaining != null)
                        Text(
                          remaining < 0
                              ? l10n.entryBudgetOver(f.kcal(-remaining))
                              : l10n.entryBudgetLeft(f.kcal(remaining)),
                          style: t.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: remaining < 0 ? mc.negative : p.text, fontFeatures: AppType.tabular),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Calories left of the meal day's goal once [deltaKcal] more are counted;
  /// null without a goal or a meal date. The day's saved meals already hold
  /// everything logged so far (the editor autosaves), so [deltaKcal] is only
  /// what this entry adds or changes.
  double? _remainingAfter(WidgetRef ref, double deltaKcal) {
    final at = mealDateTime;
    if (at == null) return null;
    final goal = ref.watch(settingsControllerProvider).value?.dailyCalorieGoal;
    if (goal == null || goal <= 0) return null;
    final day = ref.watch(mealsOnDayProvider(dateOnly(at.toLocal()))).value;
    if (day == null) return null;
    final logged = day.fold<double>(0, (sum, m) => sum + m.totalCalories);
    return goal - logged - deltaKcal;
  }
}

/// The 56 dp round − / + button of the quantity stepper.
class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(56),
        minimumSize: const Size.square(56),
        backgroundColor: p.control,
        foregroundColor: p.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
    );
  }
}
