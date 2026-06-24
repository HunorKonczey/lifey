import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/adaptive_app_bar.dart';
import '../../../shared/widgets/nav_collapse_controller.dart';
import '../../../shared/widgets/pill_tab_bar.dart';
import '../../../shared/widgets/shell_fab.dart';
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
      tabIndex: 2,
      icon: fab.icon,
      label: fab.label,
      onPressed: fab.onPressed,
      extended: true,
    ));
  }

  void _logSession() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LogSessionScreen()),
    );
  }

  void _newTemplate() {
    Navigator.of(context).push(
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusTop = MediaQuery.paddingOf(context).top;

    ref.listen(activeShellTabProvider, (_, next) {
      if (next == 2) _pushFab();
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
                      SessionsTab(),
                      TemplatesTab(),
                      ExercisesTab(),
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
                    child: AdaptiveAppBar(title: l10n.workoutsTitle),
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

// Spacer that matches the combined height of the floating header.
// Rebuilds on collapse state changes so content stays flush beneath the header.
//
// Heights: AdaptiveAppBar 58→44 (expanded→collapsed) + PillTabBar 54 (fixed:
// 38px content + 8px top + 8px bottom padding) + 8px top offset from status bar.
class _HeaderSpacer extends StatelessWidget {
  const _HeaderSpacer({required this.statusTop});

  final double statusTop;

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
