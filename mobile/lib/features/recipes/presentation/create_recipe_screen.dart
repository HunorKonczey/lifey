import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nutrition/domain/food.dart';
import '../../nutrition/presentation/widgets/add_meal_entry_sheet.dart';
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

  bool get _isEditing => widget.recipe != null;

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _name = TextEditingController(text: recipe?.name ?? '');
    _description = TextEditingController(text: recipe?.description ?? '');
    if (recipe != null) {
      for (final ing in recipe.ingredients) {
        // Only clientId + name are needed downstream; macros aren't sent on save.
        _ingredients.add((
          food: Food(
            clientId: ing.foodClientId,
            name: ing.foodName,
            caloriesPer100g: 0,
            proteinPer100g: 0,
          ),
          grams: ing.quantityInGrams,
          ));
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _addIngredient() async {
    final draft = await showModalBottomSheet<MealEntryDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddMealEntrySheet(),
    );
    if (draft != null) {
      setState(() => _ingredients.add((food: draft.food, grams: draft.grams)));
    }
  }

  Future<void> _save() async {
    if (_saving) return; // guard against a fast double-tap creating two recipes
    final messenger = ScaffoldMessenger.of(context);
    if (_name.text.trim().isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter a name')));
      return;
    }
    if (_ingredients.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Add at least one ingredient')));
      return;
    }
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final description = _description.text.trim();
    final ingredients = _ingredients
        .map((e) => RecipeIngredientInput(foodClientId: e.food.clientId, grams: e.grams))
        .toList();
    try {
      final notifier = ref.read(recipeControllerProvider.notifier);
      if (_isEditing) {
        await notifier.updateRecipe(
          widget.recipe!.clientId,
          name: _name.text.trim(),
          description: description.isEmpty ? null : description,
          ingredients: ingredients,
        );
      } else {
        await notifier.createRecipe(
          name: _name.text.trim(),
          description: description.isEmpty ? null : description,
          ingredients: ingredients,
        );
      }
      navigator.pop();
    } catch (_) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(
            content: Text("Couldn't save the recipe. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit recipe' : 'New recipe'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ingredients',
                  style: Theme.of(context).textTheme.labelLarge),
              TextButton.icon(
                onPressed: _addIngredient,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_ingredients.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No ingredients added yet'),
            )
          else
            ..._ingredients.asMap().entries.map((entry) {
              final ing = entry.value;
              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: ListTile(
                  title: Text(ing.food.name),
                  subtitle: Text('${ing.grams.toStringAsFixed(0)} g'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        setState(() => _ingredients.removeAt(entry.key)),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
