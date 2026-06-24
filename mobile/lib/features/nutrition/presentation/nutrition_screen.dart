import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../../../shared/widgets/pill_tab_bar.dart';
import '../../../shared/widgets/shell_fab.dart';
import '../../recipes/presentation/create_recipe_screen.dart';
import '../../recipes/presentation/recipes_tab.dart';
import 'barcode_scanner_screen.dart';
import 'foods_tab.dart';
import 'log_meal_screen.dart';
import 'meals_tab.dart';
import 'widgets/add_food_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onSubTabChanged);
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

  void _pushFab() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final fab = _fab(l10n);
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LogMealScreen()),
    );
  }

  void _newRecipe() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateRecipeScreen()),
    );
  }

  void _openBarcodeScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
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
    final statusTop = MediaQuery.paddingOf(context).top;

    ref.listen(activeShellTabProvider, (_, next) {
      if (next == 1) _pushFab();
    });

    return Scaffold(
      body: ScrollCollapseListener(
        child: Stack(
          children: [
            // ── Content — top spacer tracks the combined floating header ──
            Column(
              children: [
                _HeaderSpacer(statusTop: statusTop),
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

            // ── Floating combined header (AppBar + PillTabBar as one unit) ─
            Positioned(
              top: statusTop + 8.0,
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
                    ),
                  ),
                  PillTabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: l10n.foodsLabel),
                      Tab(text: l10n.mealsTabLabel),
                      Tab(text: l10n.recipesTabLabel),
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

// Spacer that matches the combined height of the floating header.
// Rebuilds on collapse state changes so content stays flush beneath the header.
//
// Heights: AdaptiveAppBar 58→44 (expanded→collapsed) + PillTabBar 54 (fixed:
// 38px content + 8px top + 8px bottom padding) + 8px top offset from status bar.
class _HeaderSpacer extends StatelessWidget {
  const _HeaderSpacer({required this.statusTop});

  final double statusTop;

  // PillTabBar internal: 38 content + 8 vertical padding * 2 = 54
  static const double _pillBarH = 54.0;
  static const double _topOffset = 8.0;

  @override
  Widget build(BuildContext context) {
    final collapsed = NavCollapseScope.collapsedOf(context);
    return AnimatedContainer(
      duration: AppDuration.collapse,
      curve: AppCurve.collapse,
      height: statusTop + _topOffset + (collapsed ? 44.0 : 58.0) + _pillBarH,
    );
  }
}
