import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/weight_controller.dart';
import '../domain/weight_entry.dart';
import 'widgets/add_weight_sheet.dart';

/// Weight: list of entries with add (FAB) and swipe-to-delete.
class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});

  static final _dateLabel = DateFormat('EEE, MMM d, yyyy');

  Future<void> _openAddSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddWeightSheet(),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, WeightEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(weightControllerProvider.notifier).deleteEntry(entry.id);
      messenger.showSnackBar(const SnackBar(content: Text('Entry deleted')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't delete the entry")));
      await ref.read(weightControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weightControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Weight'), centerTitle: false),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSheet(context),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(weightControllerProvider.notifier).refresh(),
        child: state.when(
          data: (entries) => entries.isEmpty
              ? const EmptyView(
                  icon: Icons.monitor_weight_outlined,
                  title: 'No weight entries yet',
                  subtitle: 'Tap + to add your first one',
                )
              : _WeightList(
                  entries: entries,
                  onDelete: (entry) => _delete(context, ref, entry),
                  dateLabel: _dateLabel,
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.read(weightControllerProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}

class _WeightList extends StatelessWidget {
  const _WeightList({
    required this.entries,
    required this.onDelete,
    required this.dateLabel,
  });

  final List<WeightEntry> entries;
  final void Function(WeightEntry entry) onDelete;
  final DateFormat dateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Dismissible(
          key: ValueKey(entry.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: theme.colorScheme.errorContainer,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
          ),
          onDismissed: (_) => onDelete(entry),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.monitor_weight)),
            title: Text(
              '${entry.weight.toStringAsFixed(1)} kg',
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Text(dateLabel.format(entry.date)),
          ),
        );
      },
    );
  }
}
