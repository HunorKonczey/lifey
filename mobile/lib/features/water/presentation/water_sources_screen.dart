import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
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
    useRootNavigator: true,
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

    final scheme = Theme.of(context).colorScheme;
    final fabBottom = MediaQuery.of(context).viewPadding.bottom + 16;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.waterSourcesLabel),
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: () => ref.read(waterSourceControllerProvider.notifier).refresh(),
              child: state.when(
          data: (sources) => sources.isEmpty
              ? EmptyView(
                  icon: Icons.water_drop_outlined,
                  title: l10n.noWaterSourcesYetTitle,
                  subtitle: l10n.tapPlusToAddOneWaterSourceMessage,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: sources.length,
                  itemBuilder: (context, index) {
                    final source = sources[index];
                    final scheme = Theme.of(context).colorScheme;
                    final waterColor = context.metricColors.water;
                    return Card(
                      elevation: 0,
                      color: scheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _openAddSheet(context, initial: source),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: waterColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(Icons.water_drop,
                                      size: 22, color: waterColor),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(source.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.litersValue(source.volumeLiters
                                          .toStringAsFixed(2)),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                              color: scheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              SyncStatusIndicator(clientId: source.clientId),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    size: 18, color: scheme.onSurfaceVariant),
                                onPressed: () => _delete(context, ref, source),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () =>
                      ref.read(waterSourceControllerProvider.notifier).refresh(),
                ),
              ),
            ),
          ),
          // ── FAB — standard placement, 16 dp above safe area ──────────
          Positioned(
            right: 16,
            bottom: fabBottom,
            child: FloatingActionButton(
              heroTag: null,
              onPressed: () => _openAddSheet(context),
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}
