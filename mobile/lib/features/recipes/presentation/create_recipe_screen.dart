import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/error_message.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../nutrition/domain/food.dart';
import '../../nutrition/presentation/widgets/add_macros_sheet.dart';
import '../../nutrition/presentation/widgets/add_meal_entry_sheet.dart';
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

  bool get _hasMacroData => _ingredients.any((e) => e.food.caloriesPer100g > 0);

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusTop = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;
    final mc = context.metricColors;
    final liveRecipe = _liveRecipe(ref.watch(recipeControllerProvider).value ?? const []);

    return Scaffold(
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────────────────
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              statusTop + 8 + 58 + 12,
              16,
              bottomPad + 24,
            ),
            children: [
              // ── Photo ───────────────────────────────────────────────────
              _PhotoSection(
                recipe: liveRecipe,
                busy: _photoBusy,
                l10n: l10n,
                onTap: (key, hasPhoto) => _openPhotoSheet(l10n, key, hasPhoto: hasPhoto),
                onTapUnsynced: () =>
                    AppSnackbar.showError(context, title: l10n.recipePhotoNeedsSyncMessage),
              ),
              const SizedBox(height: 20),

              // ── Name ────────────────────────────────────────────────────
              _SectionLabel(label: l10n.nameLabel),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: scheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: l10n.nameLabel,
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Description ─────────────────────────────────────────────
              _SectionLabel(label: l10n.descriptionOptionalLabel),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: scheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: l10n.descriptionOptionalLabel,
                  filled: true,
                  fillColor: scheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 20),

              // ── Servings ────────────────────────────────────────────────
              _SectionLabel(label: l10n.servingsLabel),
              const SizedBox(height: 8),
              _ServingsStepper(
                value: _servings,
                onDecrement: _servings > _minServings ? _decrementServings : null,
                onIncrement: _servings < _maxServings ? _incrementServings : null,
              ),

              const SizedBox(height: 20),

              // ── Favorite toggle ─────────────────────────────────────────
              GestureDetector(
                onTap: () {
                  setState(() => _favorite = !_favorite);
                  if (_isEditing || _recipeClientId != null) _autoSave();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _favorite ? Icons.star : Icons.star_border,
                        size: 20,
                        color: _favorite ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _favorite ? l10n.removeFavorite : l10n.markFavorite,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: scheme.onSurface,
                          ),
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

              const SizedBox(height: 20),

              // ── Ingredients ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionLabel(label: l10n.ingredientsLabel),
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
                        onTap: _addIngredient,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Ingredient entries
              ..._ingredients.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _IngredientCard(
                      food: e.value.food,
                      grams: e.value.grams,
                      onTap: () => _editIngredient(e.key),
                      onRemove: () => _removeIngredient(e.key),
                    ),
                  )),

              // Dashed "add another ingredient" placeholder
              _AddAnotherButton(
                label: l10n.addFoodButton,
                onTap: _addIngredient,
              ),

              // ── Recipe total ────────────────────────────────────────────
              if (_hasMacroData) ...[
                const SizedBox(height: 12),
                _RecipeTotalCard(
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
              title: _isEditing ? l10n.editRecipeTitle : l10n.newRecipeTitle,
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
// Floating detail header
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
  // shown on the recipes list card — a wide rectangle would force BoxFit.cover
  // to crop further into the already-cropped thumbnail, zooming in more than
  // what's shown elsewhere.
  static const _size = 160.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
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
    // reaches the Container below — without it, a ListView item's cross-axis
    // constraint is tight (forced to exactly the full viewport width), so a
    // plain Container(width: _size) would just get stretched back out to
    // full width regardless of the value passed in.
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: busy
            ? null
            : () => key != null ? onTap(key, hasPhoto) : onTapUnsynced(),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: _size,
          width: _size,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
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
                    color: scheme.onSurfaceVariant.withValues(alpha: serverId != null ? 1.0 : 0.4),
                  ),
                ),
              if (busy)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
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
// Ingredient card
// ---------------------------------------------------------------------------

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({
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
    final protein = (food.proteinPer100g * grams / 100).round();
    return '${grams.toStringAsFixed(0)} g · $kcal kcal · ${protein}g P';
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
// "Add another" dashed placeholder
// ---------------------------------------------------------------------------

class _AddAnotherButton extends StatelessWidget {
  const _AddAnotherButton({required this.label, required this.onTap});

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
// Recipe total card
// ---------------------------------------------------------------------------

class _RecipeTotalCard extends StatelessWidget {
  const _RecipeTotalCard({
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
          Row(
            children: [
              Expanded(
                child: _MacroPill(
                  value: protein,
                  label: proteinLabel,
                  color: mc.protein,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroPill(
                  value: carbs,
                  label: carbsLabel,
                  color: mc.carbs,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroPill(
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

class _MacroPill extends StatelessWidget {
  const _MacroPill({
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
// Servings stepper (− value +)
// ---------------------------------------------------------------------------

class _ServingsStepper extends StatelessWidget {
  const _ServingsStepper({
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _StepperButton(icon: Icons.remove, onTap: onDecrement),
          Expanded(
            child: Center(
              child: Text(
                '$value',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          _StepperButton(icon: Icons.add, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 21,
            color: enabled ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
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
