import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final barClear = statusTop + 8.0 + 58.0;

    ref.listen(activeShellTabProvider, (_, next) {
      if (next == 2) _pushFab();
    });

    return Scaffold(
      body: ScrollCollapseListener(
        child: Stack(
          children: [
            // ── Pinned layout: space → TabBar → content ───────────────────
            Column(
              children: [
                SizedBox(height: barClear),
                PillTabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: l10n.sessionsTabLabel),
                    Tab(text: l10n.templatesTabLabel),
                    Tab(text: l10n.exercisesLabel),
                  ],
                ),
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

            // ── Floating top bar ──────────────────────────────────────────
            Positioned(
              top: statusTop + 8.0,
              left: 12,
              right: 12,
              child: AdaptiveAppBar(title: l10n.workoutsTitle),
            ),
          ],
        ),
      ),
    );
  }
}
