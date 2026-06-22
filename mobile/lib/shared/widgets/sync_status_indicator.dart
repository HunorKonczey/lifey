import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/outbox_writer.dart';
import '../../core/sync/sync_status_provider.dart';
import '../../l10n/app_localizations.dart';

/// Small, unobtrusive marker shown next to a record that has a queued (or
/// failed) sync operation. Renders nothing once the record has fully
/// synced. Doc section 8: "visible but unobtrusive", with retry/discard for
/// failed items.
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusByClientIdProvider)[clientId];
    if (status == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (status.state == SyncState.failed) {
      return PopupMenuButton<_FailedAction>(
        tooltip: status.lastError ?? l10n.couldNotSyncTooltip,
        icon: Icon(Icons.sync_problem, size: 20, color: theme.colorScheme.error),
        onSelected: (action) {
          final outbox = ref.read(outboxWriterProvider);
          switch (action) {
            case _FailedAction.retry:
              outbox.retry(clientId);
            case _FailedAction.discard:
              outbox.discard(clientId);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: _FailedAction.retry, child: Text(l10n.retrySyncMenuItem)),
          PopupMenuItem(value: _FailedAction.discard, child: Text(l10n.discardChangeMenuItem)),
        ],
      );
    }

    return Tooltip(
      message: status.state == SyncState.syncing ? l10n.syncingTooltip : l10n.waitingToSyncTooltip,
      child: Icon(Icons.cloud_sync_outlined, size: 18, color: theme.colorScheme.outline),
    );
  }
}

enum _FailedAction { retry, discard }
