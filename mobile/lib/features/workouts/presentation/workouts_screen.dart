import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ads/banner_ad_slot.dart';
import '../../../core/ads/nav_reserved_space.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/date_range_filter_bar.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../../../shared/widgets/pill_tab_bar.dart';
import '../../../shared/widgets/shell_fab.dart';
import '../application/exercise_controller.dart';
import '../domain/exercise_enums.dart';
import 'create_template_screen.dart';
import 'exercises_tab.dart';
import 'quick_start_sheet.dart';
import 'sessions_tab.dart';
import 'template_picker_screen.dart';
import 'templates_tab.dart';
import 'widgets/add_exercise_sheet.dart';
import 'widgets/workouts_filter_sheet.dart';

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
/// A `NestedScrollView`: the large-title `LifeyHeader` (with the filter
/// button) collapses as the active tab scrolls, the `PillTabBar` under it stays
/// pinned (docs/redesign/77-mobile-redesign-plan.md R3.1).
class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// One page-storage bucket per tab. Keyless scrollables all save their offset
  /// under the same empty identifier, so a shared bucket makes a tab open
  /// scrolled to wherever the *previous* tab was — with a short list that is
  /// past its end, the header collapsed and the list out of sight.
  final _tabBuckets = List.generate(3, (_) => PageStorageBucket());

  /// 46 px pill bar + 8 px above and below (`PillTabBar`).
  static const double _tabBarExtent = 62;

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
      onLongPress:
          _tabController.index == 0 ? () => showQuickStartSheet(context) : null,
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

  ({IconData icon, String label, VoidCallback onPressed}) _fab(
      AppLocalizations l10n) {
    switch (_tabController.index) {
      case 0:
        return (
          icon: Icons.play_arrow_rounded,
          label: l10n.startWorkoutButtonLabel,
          onPressed: _logSession
        );
      case 1:
        return (
          icon: Icons.add,
          label: l10n.templateFabLabel,
          onPressed: _newTemplate
        );
      default:
        return (
          icon: Icons.add,
          label: l10n.exerciseFabLabel,
          onPressed: _addExercise
        );
    }
  }

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

  /// Whether a filter other than the default is active on the current tab —
  /// the dot on the header's filter button.
  bool get _filterActive => switch (_tabController.index) {
        0 => _sessionFilter != DateRangeFilter.week ||
            _sessionKindFilterValue.isNotEmpty,
        2 => _exerciseCategoryFilter != null,
        _ => false,
      };

  void _openFilterSheet() {
    final l10n = AppLocalizations.of(context)!;
    if (_tabController.index == 0) {
      showSessionsFilterSheet(
        context,
        range: _sessionFilter,
        kind: _sessionKindFilterValue,
        onRange: (r) => setState(() => _sessionFilter = r),
        onKind: (k) => setState(() => _sessionKindFilterValue = k),
      );
    } else {
      final exercises = ref.read(exerciseControllerProvider).value ?? const [];
      showExercisesFilterSheet(
        context,
        category: _exerciseCategoryFilter,
        categories: [
          for (final c in kMuscleGroups)
            if (exercises.any((e) => e.category == c))
              (value: c, label: muscleGroupLabel(l10n, c)),
        ],
        onCategory: (c) => setState(() => _exerciseCategoryFilter = c),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
            // The large title collapses as the active tab scrolls; the pill
            // tab bar stays pinned under it (canvas Lifey 3 › 3.1).
            Positioned.fill(
              child: NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  // One pinned sliver — the title with the tab bar under it —
                  // absorbed as a whole, so each tab's list can leave room for
                  // it (OverlapInsetScope) instead of starting behind it.
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                        context),
                    sliver: LifeyHeader(
                      title: l10n.workoutsTitle,
                      actions: [
                        if (_tabController.index != 1)
                          HeaderIconButton(
                            icon: Icons.tune_rounded,
                            tooltip: l10n.workoutsFilterTitle,
                            showDot: _filterActive,
                            onPressed: _openFilterSheet,
                          ),
                      ],
                      bottomHeight: _tabBarExtent,
                      bottom: PillTabBar(
                        controller: _tabController,
                        horizontalMargin: AppSpacing.screen,
                        tabs: [
                          Tab(text: l10n.sessionsTabLabel),
                          Tab(text: l10n.templatesTabLabel),
                          Tab(text: l10n.exercisesLabel),
                        ],
                      ),
                    ),
                  ),
                ],
                body: Builder(
                  builder: (context) => OverlapInsetScope(
                    handles: [
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                    ],
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        PageStorage(
                          bucket: _tabBuckets[0],
                          child: SessionsTab(
                            filter: _sessionFilter,
                            kindFilter: _sessionKindFilter.kind,
                            activityTypeFilter: _sessionKindFilter.activityType,
                          ),
                        ),
                        PageStorage(
                            bucket: _tabBuckets[1],
                            child: const TemplatesTab()),
                        PageStorage(
                          bucket: _tabBuckets[2],
                          child: ExercisesTab(
                              categoryFilter: _exerciseCategoryFilter),
                        ),
                      ],
                    ),
                  ),
                ),
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
