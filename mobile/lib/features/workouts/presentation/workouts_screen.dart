import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ads/banner_ad_slot.dart';
import '../../../core/ads/nav_reserved_space.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/date_range_filter_bar.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../../../shared/widgets/pill_tab_bar.dart';
import '../../../shared/widgets/shell_fab.dart';
import '../application/exercise_controller.dart';
import '../domain/activity_type.dart';
import '../domain/exercise_enums.dart';
import 'create_template_screen.dart';
import 'exercises_tab.dart';
import 'quick_start_sheet.dart';
import 'sessions_tab.dart';
import 'template_picker_screen.dart';
import 'templates_tab.dart';
import 'widgets/add_exercise_sheet.dart';

/// Bumped to force [WorkoutsScreen] back onto its "Sessions" sub-tab —
/// `CardioSessionScreen._finish` requests this so the summary screen's
/// back button always lands where the just-finished session is visible
/// (docs/cardio/59-cardio-implementation-plan.md), regardless of which
/// Workouts sub-tab (or which shell tab entirely) was active before the
/// workout started. A plain counter, not a bool: `ref.listen` only fires
/// on a value *change*, so a second request while already sitting on
/// Sessions still needs a new value to re-trigger the jump.
class _WorkoutsSessionsTabRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

final workoutsSessionsTabRequestProvider =
    NotifierProvider<_WorkoutsSessionsTabRequestNotifier, int>(
  _WorkoutsSessionsTabRequestNotifier.new,
);

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

  // Empty-string sentinel = "Mind" (all kinds). Otherwise 'STRENGTH',
  // 'CARDIO' (any cardio type), or a specific `kActivityTypes` code — see
  // `_decodeSessionKindFilter` (docs/cardio/59-cardio-implementation-plan.md
  // C1.7). Encoded as one value, not two, so picking a fresh option can
  // never leave a stale secondary selection behind.
  String _sessionKindFilterValue = '';

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
      // Only the Sessions tab's FAB (plain-tap already starts a workout via
      // the template picker) gets the quick-start long-press
      // (docs/cardio/59-cardio-implementation-plan.md C2.7, §3.1) — the
      // Templates/Exercises tabs' FABs create different things entirely,
      // and a long-press there would open a sheet unrelated to what the
      // button says it does.
      onLongPress: _tabController.index == 0 ? () => showQuickStartSheet(context) : null,
    ));
  }

  void _logSession() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const TemplatePickerScreen()),
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

  /// Decodes [_sessionKindFilterValue] into the `(kind, activityType)` pair
  /// `SessionsTab` filters on — see `matchesSessionKindFilter`.
  ({String? kind, String? activityType}) get _sessionKindFilter {
    return switch (_sessionKindFilterValue) {
      '' => (kind: null, activityType: null),
      'STRENGTH' => (kind: 'STRENGTH', activityType: null),
      'CARDIO' => (kind: 'CARDIO', activityType: null),
      final type => (kind: 'CARDIO', activityType: type),
    };
  }

  String _sessionKindFilterLabel(AppLocalizations l10n) {
    return switch (_sessionKindFilterValue) {
      '' => l10n.allFilterLabel,
      'STRENGTH' => l10n.activityTypeStrength,
      'CARDIO' => l10n.sessionKindCardioLabel,
      final type => activityTypeLabel(l10n, type),
    };
  }

  PopupMenuItem<String> _sessionKindFilterMenuItem(
    BuildContext context, {
    required String value,
    required String label,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        SizedBox(
          width: 20,
          child: _sessionKindFilterValue == value
              ? Icon(Icons.check, size: 16, color: scheme.primary)
              : null,
        ),
        const SizedBox(width: 4),
        Text(label),
      ]),
    );
  }

  Widget? _buildTrailingFilter(BuildContext context, AppLocalizations l10n) {
    switch (_tabController.index) {
      case 0:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LabeledFilterButton(
              label: _sessionKindFilterLabel(l10n),
              onSelected: (v) => setState(() => _sessionKindFilterValue = v),
              items: [
                _sessionKindFilterMenuItem(context, value: '', label: l10n.allFilterLabel),
                _sessionKindFilterMenuItem(context,
                    value: 'STRENGTH', label: l10n.activityTypeStrength),
                const PopupMenuDivider(),
                _sessionKindFilterMenuItem(context,
                    value: 'CARDIO', label: l10n.sessionKindCardioLabel),
                for (final type in kActivityTypes)
                  _sessionKindFilterMenuItem(context,
                      value: type, label: activityTypeLabel(l10n, type)),
              ],
            ),
            const SizedBox(width: 4),
            DateRangeFilterButton(
              value: _sessionFilter,
              onChanged: (f) => setState(() => _sessionFilter = f),
            ),
          ],
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

    ref.listen(workoutsSessionsTabRequestProvider, (_, __) {
      if (_tabController.index != 0) _tabController.animateTo(0);
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
                  SessionsTab(
                    topPadding: contentTop,
                    filter: _sessionFilter,
                    kindFilter: _sessionKindFilter.kind,
                    activityTypeFilter: _sessionKindFilter.activityType,
                  ),
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
            Positioned(
              left: 0,
              right: 0,
              bottom: bannerBottom(MediaQuery.paddingOf(context).bottom),
              child: const BannerAdSlot(tabIndex: 2),
            ),
          ],
        ),
      ),
    );
  }
}
