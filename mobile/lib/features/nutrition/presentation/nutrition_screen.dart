import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../recipes/presentation/create_recipe_screen.dart';
import '../../recipes/presentation/recipes_tab.dart';
import 'foods_tab.dart';
import 'log_meal_screen.dart';
import 'meals_tab.dart';
import 'widgets/add_food_sheet.dart';

/// Nutrition: "Foods" (catalogue), "Meals" (logged meals) and "Recipes" tabs.
class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Rebuild on tab change so the FAB reflects the active tab.
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addFood() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddFoodSheet(),
    );
  }

  void _logMeal() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LogMealScreen()),
    );
  }

  void _newRecipe() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateRecipeScreen()),
    );
  }

  ({IconData icon, String label, VoidCallback onPressed}) _fab(AppLocalizations l10n) {
    switch (_tabController.index) {
      case 0:
        return (icon: Icons.add, label: l10n.foodFabLabel, onPressed: _addFood);
      case 1:
        return (icon: Icons.add, label: l10n.mealFabLabel, onPressed: _logMeal);
      default:
        return (icon: Icons.add, label: l10n.recipeFabLabel, onPressed: _newRecipe);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fab = _fab(l10n);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.nutritionTitle),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.foodsLabel),
            Tab(text: l10n.mealsTabLabel),
            Tab(text: l10n.recipesTabLabel),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          FoodsTab(),
          MealsTab(),
          RecipesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Without an explicit tag, every shell tab's FAB shares Flutter's
        // default hero tag — since StatefulShellRoute.indexedStack keeps all
        // branches mounted at once, that throws a duplicate-hero assertion.
        heroTag: null,
        onPressed: fab.onPressed,
        icon: Icon(fab.icon),
        label: Text(fab.label),
      ),
    );
  }
}
