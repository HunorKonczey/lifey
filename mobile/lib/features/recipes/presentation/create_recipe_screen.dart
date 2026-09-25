import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/error_message.dart';
import '../../../core/format/lifey_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/ds/lifey_card.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/ds/section_label.dart';
import '../../nutrition/domain/food.dart';
import '../../nutrition/presentation/widgets/add_macros_sheet.dart';
import '../../nutrition/presentation/widgets/add_meal_entry_sheet.dart';
import '../../nutrition/presentation/widgets/meal_summary_panel.dart';
import '../application/recipe_image_controller.dart';
import '../application/recipes_controller.dart';
import '../data/recipe_repository.dart';
import '../domain/recipe.dart';

/// Full-screen form for creating a recipe, or editing one when [recipe] is given.
class CreateRecipeScreen extends ConsumerStatefulWidget {
  const CreateRecipeScreen({super.key, this.recipe});

  final Recipe? recipe;

  @override
  ConsumerState<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends ConsumerState<CreateRecipeScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  final List<({Food food, double grams})> _ingredients = [];
  bool _saving = false;
  bool _pendingSave = false;
  String? _recipeClientId;
  bool _photoBusy = false;
  Timer? _debounce;
  late bool _favorite;
  late int _servings;

  static const _minServings = 1;
  static const _maxServings = 20;

  bool get _isEditing => widget.recipe != null;

  double get _totalCalories =>
      _ingredients.fold(0, (s, e) => s + e.food.caloriesPer100g * e.grams / 100);
  double get _totalProtein =>
      _ingredients.fold(0, (s, e) => s + e.food.proteinPer100g * e.grams / 100);
  double get _totalCarbs =>
      _ingredients.fold(0, (s, e) => s + (e.food.carbsPer100g ?? 0) * e.grams / 100);
  double get _totalFat =>
      _ingredients.fold(0, (s, e) => s + (e.food.fatPer100g ?? 0) * e.grams / 100);

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _name = TextEditingController(text: recipe?.name ?? '');
    _description = TextEditingController(text: recipe?.description ?? '');
    _favorite = recipe?.favorite ?? false;
    _servings = recipe?.servings ?? 1;
    if (recipe != null) {
      for (final ing in recipe.ingredients) {
        final q = ing.quantityInGrams;
        _ingredients.add((
          food: Food(
            clientId: ing.foodClientId,
            name: ing.foodName,
            caloriesPer100g: q > 0 ? ing.calories / q * 100 : 0,
            proteinPer100g: q > 0 ? ing.protein / q * 100 : 0,
            carbsPer100g: q > 0 ? ing.carbs / q * 100 : 0,
            fatPer100g: q > 0 ? ing.fat / q * 100 : 0,
          ),
          grams: q,
        ));
      }
    }
    _name.addListener(_onTextChanged);
    _description.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!_isEditing && _recipeClientId == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _autoSave);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _addIngredient() async {
    final draft = await showModalBottomSheet<MealEntryDraft>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddMealEntrySheet(),
    );
    if (draft != null) {
      setState(() => _ingredients.add((food: draft.food, grams: draft.grams)));
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
      setState(() => _ingredients.add((food: draft.food, grams: draft.grams)));
      _autoSave();
    }
  }

  Future<void> _editIngredient(int index) async {
    final current = _ingredients[index];
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
      setState(() => _ingredients[index] = (food: draft.food, grams: draft.grams));
      _autoSave();
    }
  }

  void _removeIngredient(int index) {
    setState(() => _ingredients.removeAt(index));
    _autoSave();
  }

  void _decrementServings() {
    if (_servings <= _minServings) return;
    setState(() => _servings--);
    if (_isEditing || _recipeClientId != null) _autoSave();
  }

  void _incrementServings() {
    if (_servings >= _maxServings) return;
    setState(() => _servings++);
    if (_isEditing || _recipeClientId != null) _autoSave();
  }

  Future<void> _autoSave() async {
    if (_ingredients.isEmpty) return;
    final name = _name.text.trim();
    if (name.isEmpty) return;
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
          title: AppLocalizations.of(context)!.couldNotSaveRecipeMessage,
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
    final notifier = ref.read(recipeControllerProvider.notifier);
    final name = _name.text.trim();
    final description = _description.text.trim();
    final ingredients = _ingredients
        .map((e) => RecipeIngredientInput(foodClientId: e.food.clientId, grams: e.grams))
        .toList();
    final id = _isEditing ? widget.recipe!.clientId : _recipeClientId;
    if (id != null) {
      await notifier.updateRecipe(
        id,
        name: name,
        description: description.isEmpty ? null : description,
        favorite: _favorite,
        servings: _servings,
        ingredients: ingredients,
      );
    } else {
      _recipeClientId = await notifier.createRecipe(
        name: name,
        description: description.isEmpty ? null : description,
        favorite: _favorite,
        servings: _servings,
        ingredients: ingredients,
      );
    }
  }

  /// The current clientId this screen is editing/creating, or null if
  /// nothing has been saved yet (brand-new recipe, name still empty).
  String? get _effectiveClientId => widget.recipe?.clientId ?? _recipeClientId;

  /// The recipe's live state from the watched stream, so the photo section
  /// picks up a serverId (and thus becomes usable) as soon as a just-created
  /// recipe finishes its first sync, without the user needing to leave and
  /// reopen this screen.
  Recipe? _liveRecipe(List<Recipe> recipes) {
    final clientId = _effectiveClientId;
    if (clientId == null) return null;
    for (final r in recipes) {
      if (r.clientId == clientId) return r;
    }
    return widget.recipe;
  }

  void _openPhotoSheet(AppLocalizations l10n, RecipeImageKey key, {required bool hasPhoto}) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        final scheme = Theme.of(sheetCtx).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: scheme.primary),
              title: Text(l10n.takePhotoAction),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pickAndUploadPhoto(ImageSource.camera, key, l10n);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: scheme.primary),
              title: Text(l10n.chooseFromGalleryAction),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pickAndUploadPhoto(ImageSource.gallery, key, l10n);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline, color: scheme.error),
                title: Text(l10n.removePhotoAction, style: TextStyle(color: scheme.error)),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _removePhoto(key, l10n);
                },
              ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
          ],
        );
      },
    );
  }

  Future<void> _pickAndUploadPhoto(
      ImageSource source, RecipeImageKey key, AppLocalizations l10n) async {
    if (_photoBusy) return;
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 90);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
      return;
    }
    if (picked == null) return;

    setState(() => _photoBusy = true);
    try {
      await ref.read(recipeImageControllerProvider).upload(key, File(picked.path));
      if (mounted) AppSnackbar.showSuccess(context, title: l10n.recipePhotoUpdatedMessage);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto(RecipeImageKey key, AppLocalizations l10n) async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);
    try {
      await ref.read(recipeImageControllerProvider).remove(key);
      if (mounted) AppSnackbar.showSuccess(context, title: l10n.recipePhotoRemovedMessage);
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, title: friendlyError(e));
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  /// "Save": the recipe is autosaved on every change, so this flushes a
  /// pending text edit, waits for a save in flight and closes.
  Future<void> _saveAndClose() async {
    _debounce?.cancel();
    if (_isEditing || _recipeClientId != null) await _autoSave();
    while (mounted && (_saving || _pendingSave)) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final p = context.palette;
    final f = LifeyFormat.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final liveRecipe = _liveRecipe(ref.watch(recipeControllerProvider).value ?? const []);

    return Scaffold(
      appBar: LifeySubpageHeader(
        title: _isEditing ? l10n.editRecipeTitle : l10n.newRecipeTitle,
        actions: [
          FilledButton(
            onPressed: _saveAndClose,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44), tapTargetSize: MaterialTapTargetSize.padded),
            child: Text(l10n.saveButton),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.s8, AppSpacing.screen, AppSpacing.s24),
        children: [
          _PhotoSection(
            recipe: liveRecipe,
            busy: _photoBusy,
            l10n: l10n,
            onTap: (key, hasPhoto) => _openPhotoSheet(l10n, key, hasPhoto: hasPhoto),
            onTapUnsynced: () => AppSnackbar.showError(context, title: l10n.recipePhotoNeedsSyncMessage),
          ),
          const SizedBox(height: AppSpacing.s20),
          SectionLabel(l10n.nameLabel),
          const SizedBox(height: AppSpacing.s4),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l10n.nameLabel),
          ),
          const SizedBox(height: AppSpacing.s16),
          SectionLabel(l10n.descriptionOptionalLabel),
          const SizedBox(height: AppSpacing.s4),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(hintText: l10n.descriptionOptionalLabel, alignLabelWithHint: true),
          ),
          const SizedBox(height: AppSpacing.s16),
          SectionLabel(l10n.servingsLabel),
          const SizedBox(height: AppSpacing.s4),
          LifeyCard(
            padding: const EdgeInsets.all(AppSpacing.s8),
            child: Row(
              children: [
                _StepperButton(
                  icon: Icons.remove_rounded,
                  onPressed: _servings > _minServings ? _decrementServings : null,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      f.integer(_servings),
                      style: TextStyle(
                        fontFamily: AppType.fontFamily,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                        fontFeatures: AppType.tabular,
                      ),
                    ),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add_rounded,
                  onPressed: _servings < _maxServings ? _incrementServings : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          LifeyCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            onTap: () {
              setState(() => _favorite = !_favorite);
              if (_isEditing || _recipeClientId != null) _autoSave();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  Icon(
                    _favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 22,
                    color: _favorite ? context.metricColors.carbs : p.text2,
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text(
                      _favorite ? l10n.removeFavorite : l10n.markFavorite,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 15, color: p.text),
                    ),
                  ),
                  Switch(
                    value: _favorite,
                    onChanged: (v) {
                      setState(() => _favorite = v);
                      if (_isEditing || _recipeClientId != null) _autoSave();
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_ingredients.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s16),
            SectionLabel(l10n.recipeIngredientsSectionCount(_ingredients.length)),
            const SizedBox(height: AppSpacing.s8),
            ListGroup(
              dividerInset: AppSpacing.s16,
              children: [
                for (final (i, entry) in _ingredients.indexed)
                  _IngredientRow(
                    food: entry.food,
                    grams: entry.grams,
                    onTap: () => _editIngredient(i),
                    onRemove: () => _removeIngredient(i),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.s16),
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
                    onTap: _addIngredient,
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
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ingredients.isNotEmpty
          ? Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.s12, AppSpacing.s8, AppSpacing.s12, math.max(bottomInset, AppSpacing.s12)),
              child: MealSummaryPanel(
                label: l10n.recipeTotalLabel,
                calories: _totalCalories,
                protein: _totalProtein,
                carbs: _totalCarbs,
                fat: _totalFat,
              ),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Photo section — tap to take/pick/remove the recipe's photo. Disabled
// (shows a "save first" hint on tap) until the recipe has a serverId, since
// the upload endpoint is keyed by it.
// ---------------------------------------------------------------------------

class _PhotoSection extends ConsumerWidget {
  const _PhotoSection({
    required this.recipe,
    required this.busy,
    required this.l10n,
    required this.onTap,
    required this.onTapUnsynced,
  });

  final Recipe? recipe;
  final bool busy;
  final AppLocalizations l10n;
  final void Function(RecipeImageKey key, bool hasPhoto) onTap;
  final VoidCallback onTapUnsynced;

  // Square, so the crop shown here always matches the (also square) thumbnail
  // the recipe card crops from — a wide rectangle would force BoxFit.cover to
  // crop further into the already-cropped thumbnail.
  static const _size = 160.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final serverId = recipe?.id;
    final hasPhoto = recipe?.imageUpdatedAt != null;

    Uint8List? bytes;
    RecipeImageKey? key;
    if (serverId != null && recipe != null) {
      key = (
        clientId: recipe!.clientId,
        serverId: serverId,
        imageUpdatedAt: recipe!.imageUpdatedAt,
      );
      if (hasPhoto) {
        bytes = ref.watch(recipeThumbnailProvider(key)).value;
      }
    }

    // Align loosens the width constraint back to 0..viewport before it
    // reaches the box below — a ListView item's cross-axis constraint is
    // tight, so a plain fixed-size box would be stretched to full width.
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: busy ? null : () => key != null ? onTap(key, hasPhoto) : onTapUnsynced(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: _size,
          width: _size,
          decoration: BoxDecoration(
            color: p.nested,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (bytes != null)
                Image.memory(bytes, fit: BoxFit.cover)
              else
                Center(
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 40,
                    color: p.text2.withValues(alpha: serverId != null ? 1.0 : 0.4),
                  ),
                ),
              if (busy)
                Positioned.fill(
                  child: Container(
                    color: p.scrim,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ingredient row — name, "60 g · 8 g protein", kcal and the ⋮ menu
// ---------------------------------------------------------------------------

enum _IngredientAction { edit, remove }

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
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
    final subtitle = hasMacros
        ? l10n.mealFoodRowSubtitle(f.grams(grams), f.grams(food.proteinPer100g * grams / 100))
        : '${f.grams(grams)} g';

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.s16, top: AppSpacing.s8, bottom: AppSpacing.s8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(food.name, style: t.titleMedium!.copyWith(fontSize: 16, height: 1.25, color: p.text)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: t.bodySmall!.copyWith(fontSize: 13, height: 1.4, color: p.text2)),
                  ],
                ),
              ),
              if (hasMacros) ...[
                const SizedBox(width: AppSpacing.s8),
                ListRowValue(value: f.kcal(food.caloriesPer100g * grams / 100), unit: 'kcal', size: 16),
              ],
              PopupMenuButton<_IngredientAction>(
                tooltip: l10n.mealFoodMenuTooltip,
                icon: Icon(Icons.more_vert_rounded, color: p.text2),
                onSelected: (a) => switch (a) {
                  _IngredientAction.edit => onTap(),
                  _IngredientAction.remove => onRemove(),
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: _IngredientAction.edit, child: Text(l10n.editMenuItem)),
                  PopupMenuItem(
                    value: _IngredientAction.remove,
                    child: Text(l10n.removeButton, style: TextStyle(color: context.metricColors.heart)),
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
// Action tile and stepper button
// ---------------------------------------------------------------------------

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: AppSpacing.s12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: foreground),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge!
                      .copyWith(fontWeight: FontWeight.w700, height: 1.2, color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 48 dp − / + button of the servings stepper; dimmed at the limit.
class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(48),
        minimumSize: const Size.square(48),
        backgroundColor: p.control,
        foregroundColor: p.text,
        disabledBackgroundColor: p.control.withValues(alpha: 0.5),
        disabledForegroundColor: p.text3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
    );
  }
}
