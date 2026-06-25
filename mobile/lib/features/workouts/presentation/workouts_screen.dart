import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/date_range_filter_bar.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../../../shared/widgets/pill_tab_bar.dart';
import '../../../shared/widgets/shell_fab.dart';
import '../application/exercise_controller.dart';
import '../domain/exercise_enums.dart';
import 'create_template_screen.dart';
import 'exercises_tab.dart';
import 'log_session_screen.dart';
import 'sessions_tab.dart';
import 'templates_tab.dart';
import 'widgets/add_exercise_sheet.dart';

/// Workouts: "Sessions" (logged workouts), "Templates", and "Exercises" tabs.
///
/// The AdaptiveAppBar + PillTabBar form a single floating header unit that
/// collapses together on scroll, matching the dashboard's header behaviour.
class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateRangeFilter _sessionFilter = DateRangeFilter.week;
  String? _exerciseCategoryFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onSubTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushFab());
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
      tabIndex: 2,
      icon: fab.icon,
      label: fab.label,
      onPressed: fab.onPressed,
      extended: true,
    ));
  }

  void _logSession() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const LogSessionScreen()),
    );
  }

  void _newTemplate() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const CreateTemplateScreen()),
    );
  }

  void _addExercise() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddExerciseSheet(),
    );
  }

  ({IconData icon, String label, VoidCallback onPressed}) _fab(AppLocalizations l10n) {
    switch (_tabController.index) {
      case 0:
        return (icon: Icons.add, label: l10n.logFabLabel, onPressed: _logSession);
      case 1:
        return (icon: Icons.add, label: l10n.templateFabLabel, onPressed: _newTemplate);
      default:
        return (icon: Icons.add, label: l10n.exerciseFabLabel, onPressed: _addExercise);
    }
  }

  // Empty-string sentinel represents "All" for the exercises category filter
  // (PopupMenuButton<String> doesn't fire onSelected for null values).
  static const _kCategoryAll = '';

  Widget? _buildTrailingFilter(BuildContext context, AppLocalizations l10n) {
    switch (_tabController.index) {
      case 0:
        return DateRangeFilterButton(
          value: _sessionFilter,
          onChanged: (f) => setState(() => _sessionFilter = f),
        );
      case 2:
        final exercises =
            ref.watch(exerciseControllerProvider).value ?? const [];
        final categories = kMuscleGroups
            .where((c) => exercises.any((e) => e.category == c))
            .toList();
        final scheme = Theme.of(context).colorScheme;
        final label = _exerciseCategoryFilter == null
            ? l10n.allFilterLabel
            : muscleGroupLabel(l10n, _exerciseCategoryFilter!);
        return LabeledFilterButton(
          label: label,
          onSelected: (v) => setState(
              () => _exerciseCategoryFilter = v == _kCategoryAll ? null : v),
          items: [
            PopupMenuItem<String>(
              value: _kCategoryAll,
              child: Row(children: [
                SizedBox(
                  width: 20,
                  child: _exerciseCategoryFilter == null
                      ? Icon(Icons.check, size: 16, color: scheme.primary)
                      : null,
                ),
                const SizedBox(width: 4),
                Text(l10n.allFilterLabel),
              ]),
            ),
            ...categories.map((c) => PopupMenuItem<String>(
                  value: c,
                  child: Row(children: [
                    SizedBox(
                      width: 20,
                      child: _exerciseCategoryFilter == c
                          ? Icon(Icons.check, size: 16, color: scheme.primary)
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Text(muscleGroupLabel(l10n, c)),
                  ]),
                )),
          ],
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusTop = MediaQuery.paddingOf(context).top;
    final barTop = statusTop + 8.0;
    // AppBar expanded height + PillTabBar height (38 content + 8*2 padding)
    final contentTop = barTop + 58.0 + 54.0;

    ref.listen(activeShellTabProvider, (_, next) {
      if (next != 2) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pushFab();
      });
    });

    return Scaffold(
      body: ScrollCollapseListener(
        child: Stack(
          children: [
            // ── Content fills the screen; each tab handles its own top padding ─
            Positioned.fill(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SessionsTab(topPadding: contentTop, filter: _sessionFilter),
                  TemplatesTab(topPadding: contentTop),
                  ExercisesTab(
                    topPadding: contentTop,
                    categoryFilter: _exerciseCategoryFilter,
                  ),
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
                      title: l10n.workoutsTitle,
                      trailing: _buildTrailingFilter(context, l10n),
                    ),
                  ),
                  PillTabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: l10n.sessionsTabLabel),
                      Tab(text: l10n.templatesTabLabel),
                      Tab(text: l10n.exercisesLabel),
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
