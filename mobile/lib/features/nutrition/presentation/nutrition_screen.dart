import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../../../shared/widgets/pill_tab_bar.dart';
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
      useRootNavigator: true,
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
    final scheme = Theme.of(context).colorScheme;
    final fab = _fab(l10n);

    final statusTop = MediaQuery.paddingOf(context).top;
    final barClear = statusTop + 8.0 + 58.0;

    final fabBottom = MediaQuery.of(context).viewPadding.bottom + 100;

    return Scaffold(
      // ScrollCollapseListener at the Stack level catches scroll notifications
      // that bubble up from whichever tab's ListView is active.
      body: ScrollCollapseListener(
        child: Stack(
          children: [
            // ── Pinned layout: space → pill TabBar → content ──────────────
            Column(
              children: [
                SizedBox(height: barClear),
                PillTabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: l10n.foodsLabel),
                    Tab(text: l10n.mealsTabLabel),
                    Tab(text: l10n.recipesTabLabel),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: const [
                      FoodsTab(),
                      MealsTab(),
                      RecipesTab(),
                    ],
                  ),
                ),
              ],
            ),

            // ── Floating top bar ──────────────────────────────────────────
            Positioned(
              top: statusTop + 8.0,
              left: 12,
              right: 12,
              child: AdaptiveAppBar(title: l10n.nutritionTitle),
            ),

            // ── FAB — above floating nav bar (84 dp fixed) + 16 dp gap ───
            Positioned(
              right: 16,
              bottom: fabBottom,
              child: FloatingActionButton.extended(
                heroTag: null,
                onPressed: fab.onPressed,
                icon: Icon(fab.icon),
                label: Text(fab.label),
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
