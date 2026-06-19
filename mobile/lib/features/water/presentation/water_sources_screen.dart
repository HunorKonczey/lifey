import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../application/water_source_controller.dart';
import '../domain/water_source.dart';
import 'widgets/add_water_source_sheet.dart';

/// Settings > Water sources: manage reusable intake presets (name + volume).
class WaterSourcesScreen extends ConsumerWidget {
  const WaterSourcesScreen({super.key});

  Future<void> _openAddSheet(BuildContext context, {WaterSource? initial}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddWaterSourceSheet(initial: initial),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, WaterSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete water source?'),
        content: Text('"${source.name}" will be removed. Past entries logged from it are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(waterSourceControllerProvider.notifier).deleteSource(source.id);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't delete the water source")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(waterSourceControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Water sources'), centerTitle: false),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSheet(context),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(waterSourceControllerProvider.notifier).refresh(),
        child: state.when(
          data: (sources) => sources.isEmpty
              ? const EmptyView(
                  icon: Icons.water_drop_outlined,
                  title: 'No water sources yet',
                  subtitle: 'Tap + to add one, e.g. "Water Bottle" = 0.75L',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: sources.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final source = sources[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.water_drop)),
                      title: Text(source.name),
                      subtitle: Text('${source.volumeLiters.toStringAsFixed(2)} L'),
                      onTap: () => _openAddSheet(context, initial: source),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, ref, source),
                      ),
                    );
                  },
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.read(waterSourceControllerProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}
