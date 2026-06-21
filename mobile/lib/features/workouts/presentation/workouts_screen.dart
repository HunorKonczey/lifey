import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddExerciseSheet(),
    );
  }

  ({IconData icon, String label, VoidCallback onPressed}) get _fab {
    switch (_tabController.index) {
      case 0:
        return (icon: Icons.add, label: 'Log', onPressed: _logSession);
      case 1:
        return (icon: Icons.add, label: 'Template', onPressed: _newTemplate);
      default:
        return (icon: Icons.add, label: 'Exercise', onPressed: _addExercise);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fab = _fab;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sessions'),
            Tab(text: 'Templates'),
            Tab(text: 'Exercises'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          SessionsTab(),
          TemplatesTab(),
          ExercisesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // See nutrition_screen.dart: shell tabs stay mounted simultaneously
        // (IndexedStack), so each FAB needs a non-default hero tag.
        heroTag: null,
        onPressed: fab.onPressed,
        icon: Icon(fab.icon),
        label: Text(fab.label),
      ),
    );
  }
}
