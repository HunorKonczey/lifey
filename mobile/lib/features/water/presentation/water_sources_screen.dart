import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/sync_status_indicator.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteWaterSourceQuestionTitle),
        content: Text(l10n.deleteWaterSourceConfirmMessage(source.name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.cancelButton)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.deleteButton)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(waterSourceControllerProvider.notifier).deleteSource(source.clientId);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.couldNotDeleteWaterSourceMessage)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(waterSourceControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.waterSourcesLabel), centerTitle: false),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => _openAddSheet(context),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(waterSourceControllerProvider.notifier).refresh(),
        child: state.when(
          data: (sources) => sources.isEmpty
              ? EmptyView(
                  icon: Icons.water_drop_outlined,
                  title: l10n.noWaterSourcesYetTitle,
                  subtitle: l10n.tapPlusToAddOneWaterSourceMessage,
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
                      subtitle: Text(l10n.litersValue(source.volumeLiters.toStringAsFixed(2))),
                      onTap: () => _openAddSheet(context, initial: source),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SyncStatusIndicator(clientId: source.clientId),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(context, ref, source),
                          ),
                        ],
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
