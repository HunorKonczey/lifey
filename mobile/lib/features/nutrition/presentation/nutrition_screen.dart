import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/date_range_filter_bar.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../../../shared/widgets/pill_tab_bar.dart';
import '../../../shared/widgets/shell_fab.dart';
import '../../recipes/presentation/create_recipe_screen.dart';
import '../../recipes/presentation/recipes_tab.dart';
import 'barcode_scanner_screen.dart';
import 'foods_tab.dart';
import 'log_meal_screen.dart';
import 'macros_tab.dart';
import 'meals_tab.dart';
import 'widgets/add_food_sheet.dart';

class _NutritionPendingTabNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? tab) => state = tab;
}

/// Set this before navigating to `/nutrition` to open a specific sub-tab
/// (0 = Foods, 1 = Meals, 2 = Recipes, 3 = Macros). Cleared by [NutritionScreen] after use.
final nutritionPendingTabProvider =
    NotifierProvider<_NutritionPendingTabNotifier, int?>(
      _NutritionPendingTabNotifier.new,
    );

/// Nutrition: "Foods" (catalogue), "Meals" (logged meals) and "Recipes" tabs.
///
/// The AdaptiveAppBar + PillTabBar form a single floating header unit that
/// collapses together on scroll, matching the dashboard's header behaviour.
class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateRangeFilter _mealsFilter = DateRangeFilter.today;
  DateRangeFilter _macrosFilter = DateRangeFilter.week;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(_onSubTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pushFab();
      _consumePendingTab();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onSubTabChanged() {
    setState(() {});
    _pushFab();
  }

  void _consumePendingTab() {
    if (!mounted) return;
    final pending = ref.read(nutritionPendingTabProvider);
    if (pending != null) {
      _tabController.animateTo(pending);
      ref.read(nutritionPendingTabProvider.notifier).set(null);
    }
  }

  void _pushFab() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final fab = _fab(l10n);
    if (fab == null) {
      // Macros tab is read-only — clear the FAB so the Recipes "+" doesn't linger.
      ref.read(shellFabProvider.notifier).set(null);
      return;
    }
    ref.read(shellFabProvider.notifier).set((
      tabIndex: 1,
      icon: fab.icon,
      label: fab.label,
      onPressed: fab.onPressed,
      extended: true,
    ));
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
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const LogMealScreen()),
    );
  }

  void _newRecipe() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const CreateRecipeScreen()),
    );
  }

  Future<void> _openBarcodeScanner() async {
    final barcode = await Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode == null || !mounted) return;
    _tabController.animateTo(0);
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddFoodSheet(initialBarcode: barcode),
    );
  }

  ({IconData icon, String label, VoidCallback onPressed})? _fab(AppLocalizations l10n) {
    switch (_tabController.index) {
      case 0:
        return (icon: Icons.add, label: l10n.foodFabLabel, onPressed: _addFood);
      case 1:
        return (icon: Icons.add, label: l10n.mealFabLabel, onPressed: _logMeal);
      case 2:
        return (icon: Icons.add, label: l10n.recipeFabLabel, onPressed: _newRecipe);
      default: // 3 = Macros — read-only, no FAB
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusTop = MediaQuery.paddingOf(context).top;

    ref.listen(activeShellTabProvider, (_, next) {
      if (next != 1) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pushFab();
        _consumePendingTab();
      });
    });

    ref.listen(nutritionPendingTabProvider, (_, next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pushFab();
        _consumePendingTab();
      });
    });

    final barTop = statusTop + 8.0;
    // AppBar expanded height + PillTabBar height (38 content + 8*2 padding)
    final contentTop = barTop + 58.0 + 54.0;

    return Scaffold(
      body: ScrollCollapseListener(
        child: Stack(
          children: [
            // ── Content fills the screen; each tab handles its own top padding ─
            Positioned.fill(
              child: TabBarView(
                controller: _tabController,
                children: [
                  FoodsTab(topPadding: contentTop),
                  MealsTab(topPadding: contentTop, filter: _mealsFilter),
                  RecipesTab(topPadding: contentTop),
                  MacrosTab(topPadding: contentTop, filter: _macrosFilter),
                ],
              ),
            ),

            // ── Floating combined header (AppBar + PillTabBar as one unit) ─
            Positioned(
              top: barTop,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: AdaptiveAppBar(
                      title: l10n.nutritionTitle,
                      actions: [
                        AdaptiveAppBarAction(
                          icon: Icons.search,
                          onPressed: () {}, // TODO(new-feature #B1): food search
                        ),
                        AdaptiveAppBarAction(
                          icon: Icons.qr_code_scanner,
                          onPressed: _openBarcodeScanner,
                        ),
                      ],
                      trailing: switch (_tabController.index) {
                        1 => DateRangeFilterButton(
                            value: _mealsFilter,
                            onChanged: (f) =>
                                setState(() => _mealsFilter = f),
                          ),
                        3 => DateRangeFilterButton(
                            value: _macrosFilter,
                            onChanged: (f) =>
                                setState(() => _macrosFilter = f),
                          ),
                        _ => null,
                      },
                    ),
                  ),
                  PillTabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: l10n.foodsLabel),
                      Tab(text: l10n.mealsTabLabel),
                      Tab(text: l10n.recipesTabLabel),
                      Tab(text: l10n.macrosTabLabel),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
