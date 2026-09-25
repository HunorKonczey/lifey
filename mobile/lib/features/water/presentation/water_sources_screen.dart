import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/lifey_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/ds/lifey_header.dart';
import '../../../shared/widgets/ds/list_group.dart';
import '../../../shared/widgets/empty_view.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/sync_status_indicator.dart';
import '../application/water_source_controller.dart';
import '../domain/water_source.dart';
import 'widgets/add_water_source_sheet.dart';

/// Settings > Water sources: manage reusable intake presets (name + volume).
///
/// The sources are one grouped list (water-tinted icon holder, name, volume);
/// tapping a row edits it, and Delete lives in the row's ⋮ menu rather than
/// as a bare trash button that sits one mis-tap from the edit target
/// (docs/redesign/77-mobile-redesign-plan.md R1.7, §1 point 5).
class WaterSourcesScreen extends ConsumerWidget {
  const WaterSourcesScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, WaterSource source) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: l10n.deleteWaterSourceQuestionTitle,
      message: l10n.deleteWaterSourceConfirmMessage(source.name),
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(waterSourceControllerProvider.notifier).deleteSource(source.clientId);
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.showError(context, title: l10n.couldNotDeleteWaterSourceMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(waterSourceControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final water = context.metricColors.water;
    final p = context.palette;
    final fabBottom = MediaQuery.of(context).viewPadding.bottom + AppSpacing.s16;

    return Scaffold(
      appBar: LifeySubpageHeader(title: l10n.waterSourcesLabel),
      body: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: () => ref.read(waterSourceControllerProvider.notifier).refresh(),
              child: state.when(
                data: (sources) => sources.isEmpty
                    ? EmptyView(
                        icon: Icons.water_drop_outlined,
                        color: water,
                        title: l10n.noWaterSourcesYetTitle,
                        subtitle: l10n.tapPlusToAddOneWaterSourceMessage,
                      )
                    : ListView(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.s20,
                          AppSpacing.s8,
                          AppSpacing.s20,
                          // Clears the FAB.
                          fabBottom + 56 + AppSpacing.s16,
                        ),
                        children: [
                          ListGroup(
                            children: [
                              for (final source in sources)
                                ListRow(
                                  leading: ListIconHolder(icon: Icons.water_drop_rounded, color: water),
                                  title: source.name,
                                  subtitle: l10n.litersValue(f.litres(source.volumeLiters)),
                                  onTap: () => showAddWaterSourceSheet(context, initial: source),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SyncStatusIndicator(clientId: source.clientId),
                                      PopupMenuButton<_SourceAction>(
                                        icon: Icon(Icons.more_vert_rounded, color: p.text2),
                                        onSelected: (action) => switch (action) {
                                          _SourceAction.edit =>
                                            showAddWaterSourceSheet(context, initial: source),
                                          _SourceAction.delete => _delete(context, ref, source),
                                        },
                                        itemBuilder: (_) => [
                                          PopupMenuItem(
                                              value: _SourceAction.edit, child: Text(l10n.editMenuItem)),
                                          PopupMenuItem(
                                              value: _SourceAction.delete, child: Text(l10n.deleteButton)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () => ref.read(waterSourceControllerProvider.notifier).refresh(),
                ),
              ),
            ),
          ),
          // ── FAB — standard placement, 16 dp above safe area ──────────
          Positioned(
            right: AppSpacing.s20,
            bottom: fabBottom,
            child: FloatingActionButton(
              heroTag: null,
              tooltip: l10n.newWaterSourceTitle,
              onPressed: () => showAddWaterSourceSheet(context),
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

enum _SourceAction { edit, delete }
