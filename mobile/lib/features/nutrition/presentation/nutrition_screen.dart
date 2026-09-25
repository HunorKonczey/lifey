import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ads/banner_ad_slot.dart';
import '../../../core/ads/nav_reserved_space.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/date_range_filter_bar.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../../../shared/widgets/pill_tab_bar.dart';
import '../../../shared/widgets/shell_fab.dart';
import '../../recipes/presentation/create_recipe_screen.dart';
import '../../recipes/presentation/recipes_tab.dart';
import '../application/meal_controller.dart';
import '../domain/day_meals_summary.dart';
import '../application/selected_meal_day_provider.dart';
import '../domain/meal_days.dart';
import 'all_meals_screen.dart';
import 'barcode_scanner_screen.dart';
import 'foods_tab.dart';
import 'log_meal_screen.dart';
import 'macros_tab.dart';
import 'meals_tab.dart';
import 'widgets/add_food_sheet.dart';
import 'widgets/copy_day_sheet.dart';

class _NutritionPendingTabNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? tab) => state = tab;
}

/// Set this before navigating to `/nutrition` to open a specific sub-tab
/// (0 = Meals, 1 = Recipes, 2 = Foods, 3 = Macros). Cleared by [NutritionScreen] after use.
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
  final TextEditingController _searchController = TextEditingController();
  /// 46 px pill bar + 8 px above and below (`PillTabBar`).
  static const double _tabBarExtent = 62;

  bool _searching = false;
  String _searchQuery = '';

  /// Search only applies to catalog-like tabs: Recipes (1) and Foods (2).
  /// Meals (0) is excluded per product decision, and Macros (3) is a
  /// read-only chart with nothing to search.
  bool get _searchableTab => _tabController.index == 1 || _tabController.index == 2;

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
    _searchController.dispose();
    super.dispose();
  }

  void _onSubTabChanged() {
    // A search context (query + open state) belongs to whichever list it was
    // typed against — switching tabs would otherwise leave a Recipes search
    // silently filtering the Foods list, or an inapplicable search open on
    // Meals/Macros.
    _searchController.clear();
    setState(() {
      _searching = false;
      _searchQuery = '';
    });
    _pushFab();
  }

  void _openSearch() {
    setState(() => _searching = true);
  }

  void _closeSearch() {
    _searchController.clear();
    setState(() {
      _searching = false;
      _searchQuery = '';
    });
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
      onLongPress: null,
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

  /// Logs onto the day picked in the Meals tab's week strip.
  void _logMeal() {
    final day = effectiveMealDay(ref.read(selectedMealDayProvider), DateTime.now());
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => LogMealScreen(initialDate: day)),
    );
  }

  void _openAllMeals() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const AllMealsScreen()),
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

  Future<void> _openCopyDaySheet() async {
    final meals = ref.read(mealControllerProvider).value ?? const [];
    final hasMealsToday = meals.any((m) => DateRangeFilter.today.matches(m.dateTime));
    final picked = await showModalBottomSheet<DayMealsSummary>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CopyDaySheet(hasMealsToday: hasMealsToday),
    );
    if (picked == null || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      final copied =
          await ref.read(mealControllerProvider.notifier).copyMeals(picked.meals, DateTime.now());
      if (mounted) AppSnackbar.showSuccess(context, title: l10n.mealsCopiedMessage(copied));
    } catch (_) {
      if (mounted) AppSnackbar.showError(context, title: l10n.couldNotCopyDayMessage);
    }
  }

  ({IconData icon, String label, VoidCallback onPressed})? _fab(AppLocalizations l10n) {
    switch (_tabController.index) {
      case 0:
        return (icon: Icons.add, label: l10n.mealFabLabel, onPressed: _logMeal);
      case 1:
        return (icon: Icons.add, label: l10n.recipeFabLabel, onPressed: _newRecipe);
      case 2:
        return (icon: Icons.add, label: l10n.foodFabLabel, onPressed: _addFood);
      default: // 3 = Macros — read-only, no FAB
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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

    return Scaffold(
      body: ScrollCollapseListener(
        child: Stack(
          children: [
            // The large title collapses as the active tab scrolls; the pill
            // tab bar stays pinned under it (canvas Lifey 2 › 2.1).
            Positioned.fill(
              child: NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  if (_searching)
                    LifeySearchHeader(
                      controller: _searchController,
                      hint: _tabController.index == 1
                          ? l10n.searchRecipesHint
                          : l10n.searchFoodsHint,
                      closeTooltip: l10n.closeSearchTooltip,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      onClose: _closeSearch,
                    )
                  else
                    LifeyHeader(
                      title: l10n.nutritionTitle,
                      actions: [
                        if (_searchableTab)
                          HeaderIconButton(
                            icon: Icons.search_rounded,
                            tooltip: l10n.searchTooltip,
                            onPressed: _openSearch,
                          ),
                        if (_tabController.index == 0)
                          HeaderIconButton(
                            icon: Icons.calendar_month_rounded,
                            tooltip: l10n.allMealsTitle,
                            onPressed: _openAllMeals,
                          ),
                        HeaderIconButton(
                          icon: Icons.content_copy_rounded,
                          tooltip: l10n.copyPreviousDayAria,
                          onPressed: _openCopyDaySheet,
                        ),
                        HeaderIconButton(
                          icon: Icons.qr_code_scanner_rounded,
                          tooltip: l10n.scanBarcodeButton,
                          onPressed: _openBarcodeScanner,
                        ),
                      ],
                    ),
                  LifeyPinnedSliver(
                    height: _tabBarExtent,
                    child: PillTabBar(
                      controller: _tabController,
                      horizontalMargin: AppSpacing.screen,
                      tabs: [
                        Tab(text: l10n.mealsTabLabel),
                        Tab(text: l10n.recipesTabLabel),
                        Tab(text: l10n.foodsLabel),
                        Tab(text: l10n.macrosTabLabel),
                      ],
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    MealsTab(onCopyDay: _openCopyDaySheet),
                    RecipesTab(searchQuery: _searching ? _searchQuery : null),
                    FoodsTab(searchQuery: _searching ? _searchQuery : null),
                    const MacrosTab(),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bannerBottom(MediaQuery.paddingOf(context).bottom),
              child: const BannerAdSlot(tabIndex: 1),
            ),
          ],
        ),
      ),
    );
  }
}
