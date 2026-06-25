import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/sync_status_indicator.dart';
import '../application/exercise_controller.dart';
import '../domain/exercise.dart';
import '../domain/exercise_enums.dart';
import 'exercise_detail_screen.dart';
import 'widgets/add_exercise_sheet.dart';

// ---------------------------------------------------------------------------
// Tab
// ---------------------------------------------------------------------------

/// "Exercises" tab — category-grouped list with horizontal filter chips.
///
/// "All" chip: exercises are grouped by muscle group (kMuscleGroups order),
/// exercises without a category appear last under an "Other" bucket.
/// Any other chip: flat list filtered to that category only.
class ExercisesTab extends ConsumerStatefulWidget {
  const ExercisesTab({super.key});

  @override
  ConsumerState<ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends ConsumerState<ExercisesTab> {
  /// null = "All" (grouped view); non-null = single-category filter
  String? _categoryFilter;

  Future<void> _delete(Exercise exercise) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(exerciseControllerProvider.notifier).deleteExercise(exercise.clientId);
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.deletedExerciseMessage(exercise.name))));
    } catch (_) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.couldNotDeleteExerciseMessage(exercise.name))));
      await ref.read(exerciseControllerProvider.notifier).refresh();
    }
  }

  void _openEdit(Exercise exercise) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddExerciseSheet(exercise: exercise),
    );
  }

  void _openDetail(Exercise exercise) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseDetailScreen(exercise: exercise),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exerciseControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return RefreshIndicator(
      onRefresh: () => ref.read(exerciseControllerProvider.notifier).refresh(),
      child: state.when(
        data: (exercises) {
          if (exercises.isEmpty) {
            return EmptyView(
              icon: Icons.sports_gymnastics_outlined,
              title: l10n.noExercisesYetTitle,
              subtitle: l10n.tapPlusToAddOneMessage,
            );
          }

          // Categories that actually appear in the list (display order)
          final presentCategories = kMuscleGroups
              .where((c) => exercises.any((e) => e.category == c))
              .toList();

          final bottomPadding = EdgeInsets.fromLTRB(12, 4, 12, bottomPad + 88);

          return CustomScrollView(
            slivers: [
              // ── Filter chips ─────────────────────────────────────────────
              if (presentCategories.isNotEmpty)
                SliverToBoxAdapter(
                  child: _CategoryFilterBar(
                    categories: presentCategories,
                    selected: _categoryFilter,
                    labelBuilder: (c) => muscleGroupLabel(l10n, c),
                    allLabel: l10n.allFilterLabel,
                    onSelected: (c) => setState(() => _categoryFilter = c),
                  ),
                ),

              // ── Content ──────────────────────────────────────────────────
              if (_categoryFilter != null)
                // Single-category flat list
                _FlatList(
                  exercises:
                      exercises.where((e) => e.category == _categoryFilter).toList(),
                  padding: bottomPadding,
                  l10n: l10n,
                  onDelete: _delete,
                  onEdit: _openEdit,
                  onTap: _openDetail,
                )
              else
                // Grouped by category
                _GroupedList(
                  exercises: exercises,
                  presentCategories: presentCategories,
                  padding: bottomPadding,
                  l10n: l10n,
                  onDelete: _delete,
                  onEdit: _openEdit,
                  onTap: _openDetail,
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.read(exerciseControllerProvider.notifier).refresh(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Flat sliver (single-category filter mode)
// ---------------------------------------------------------------------------

class _FlatList extends StatelessWidget {
  const _FlatList({
    required this.exercises,
    required this.padding,
    required this.l10n,
    required this.onDelete,
    required this.onEdit,
    required this.onTap,
  });

  final List<Exercise> exercises;
  final EdgeInsets padding;
  final AppLocalizations l10n;
  final void Function(Exercise) onDelete;
  final void Function(Exercise) onEdit;
  final void Function(Exercise) onTap;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverList.builder(
        itemCount: exercises.length,
        itemBuilder: (context, i) => _ExerciseCard(
          exercise: exercises[i],
          l10n: l10n,
          showCategorySubtitle: false, // already filtered to one category
          onDelete: () => onDelete(exercises[i]),
          onEdit: () => onEdit(exercises[i]),
          onTap: () => onTap(exercises[i]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouped sliver ("All" mode)
// ---------------------------------------------------------------------------

class _GroupedList extends StatelessWidget {
  const _GroupedList({
    required this.exercises,
    required this.presentCategories,
    required this.padding,
    required this.l10n,
    required this.onDelete,
    required this.onEdit,
    required this.onTap,
  });

  final List<Exercise> exercises;
  final List<String> presentCategories;
  final EdgeInsets padding;
  final AppLocalizations l10n;
  final void Function(Exercise) onDelete;
  final void Function(Exercise) onEdit;
  final void Function(Exercise) onTap;

  @override
  Widget build(BuildContext context) {
    // Build ordered groups: present categories first (kMuscleGroups order),
    // then a null-category bucket for exercises without a category.
    final groups = <({String? category, List<Exercise> items})>[];

    for (final cat in presentCategories) {
      final items = exercises.where((e) => e.category == cat).toList();
      if (items.isNotEmpty) groups.add((category: cat, items: items));
    }

    final uncategorized = exercises.where((e) => e.category == null).toList();
    if (uncategorized.isNotEmpty) {
      groups.add((category: null, items: uncategorized));
    }

    // Flatten groups into a linear sliver list with header items interspersed.
    // Using a single SliverList keeps scroll physics uniform and lets
    // Dismissible work without nested scroll issues.
    final items = <_ListItem>[];
    for (final group in groups) {
      final label = group.category != null
          ? muscleGroupLabel(l10n, group.category!)
          : l10n.muscleGroupOther;
      items.add(_ListItem.header(label));
      for (final e in group.items) {
        items.add(_ListItem.exercise(e));
      }
    }

    return SliverPadding(
      padding: padding,
      sliver: SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return switch (item.type) {
            _ItemType.header => _SectionHeader(label: item.label!),
            _ItemType.exercise => _ExerciseCard(
                exercise: item.exercise!,
                l10n: l10n,
                showCategorySubtitle: false, // group header already shows it
                onDelete: () => onDelete(item.exercise!),
                onEdit: () => onEdit(item.exercise!),
                onTap: () => onTap(item.exercise!),
              ),
          };
        },
      ),
    );
  }
}

// Simple tagged-union to avoid two separate item lists
enum _ItemType { header, exercise }

class _ListItem {
  _ListItem.header(this.label)
      : type = _ItemType.header,
        exercise = null;

  _ListItem.exercise(this.exercise)
      : type = _ItemType.exercise,
        label = null;

  final _ItemType type;
  final String? label;
  final Exercise? exercise;
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category filter bar
// ---------------------------------------------------------------------------

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    required this.categories,
    required this.selected,
    required this.labelBuilder,
    required this.allLabel,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selected;
  final String Function(String code) labelBuilder;
  final String allLabel;
  final void Function(String? code) onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget chip({
      required String label,
      required bool isSelected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
          selected: isSelected,
          showCheckmark: false,
          backgroundColor: scheme.surfaceContainerLow,
          selectedColor: scheme.primary,
          shape: const StadiumBorder(),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          onSelected: (_) => onTap(),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          chip(
            label: allLabel,
            isSelected: selected == null,
            onTap: () => onSelected(null),
          ),
          ...categories.map((c) => chip(
                label: labelBuilder(c),
                isSelected: selected == c,
                onTap: () => onSelected(selected == c ? null : c),
              )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise card
// ---------------------------------------------------------------------------

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.l10n,
    required this.showCategorySubtitle,
    required this.onDelete,
    required this.onEdit,
    required this.onTap,
  });

  final Exercise exercise;
  final AppLocalizations l10n;

  /// When true, shows "category · equipment" subtitle.
  /// In grouped mode we suppress category (the header already shows it)
  /// and only show equipment if set.
  final bool showCategorySubtitle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onTap;

  IconData _badgeIcon() {
    if (exercise.category == 'CARDIO') return Icons.directions_run;
    if (exercise.equipment == 'BODYWEIGHT') return Icons.sports_gymnastics;
    return Icons.fitness_center;
  }

  String? _subtitle() {
    final parts = <String>[];
    if (showCategorySubtitle && exercise.category != null) {
      parts.add(muscleGroupLabel(l10n, exercise.category!));
    }
    if (exercise.equipment != null) {
      parts.add(equipmentLabel(l10n, exercise.equipment!));
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtitle = _subtitle();

    final Color badgeBg;
    final Color badgeIconColor;
    if (exercise.category != null) {
      final mc = muscleGroupColor(exercise.category!, context);
      badgeBg = mc.withValues(alpha: 0.15);
      badgeIconColor = mc;
    } else {
      badgeBg = scheme.primaryContainer;
      badgeIconColor = scheme.onPrimaryContainer;
    }

    return Dismissible(
      key: ValueKey(exercise.clientId),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 10),
        child: Icon(Icons.delete, color: scheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Card(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      _badgeIcon(),
                      size: 22,
                      color: badgeIconColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercise.name, style: theme.textTheme.bodyLarge),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                SyncStatusIndicator(clientId: exercise.clientId),
                const SizedBox(width: 4),
                PopupMenuButton<_Action>(
                  icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                  onSelected: (action) {
                    switch (action) {
                      case _Action.edit:
                        onEdit();
                      case _Action.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _Action.edit,
                      child: Text(l10n.editMenuItem),
                    ),
                    PopupMenuItem(
                      value: _Action.delete,
                      child: Text(
                        l10n.deleteButton,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Action { edit, delete }
