import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  ({IconData icon, String label, VoidCallback onPressed}) get _fab {
    switch (_tabController.index) {
      case 0:
        return (icon: Icons.add, label: 'Food', onPressed: _addFood);
      case 1:
        return (icon: Icons.add, label: 'Meal', onPressed: _logMeal);
      default:
        return (icon: Icons.add, label: 'Recipe', onPressed: _newRecipe);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fab = _fab;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Foods'),
            Tab(text: 'Meals'),
            Tab(text: 'Recipes'),
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
        onPressed: fab.onPressed,
        icon: Icon(fab.icon),
        label: Text(fab.label),
      ),
    );
  }
}
