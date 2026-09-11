import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../clients/domain/trainer_client.dart';
import '../../domain/assignment.dart';

/// What the batch actually did (frame E3).
///
/// Deliberately *not* the "failed rows, with a retry" sheet the design prompt
/// sketched: the backend runs the whole batch as one transaction
/// (docs/35-bulk-assignment-plan.md), so there are no failed rows to list —
/// either everything was written or nothing was, and the latter surfaces as an
/// error in the assign sheet instead. The one per-client outcome that exists
/// is a skip, and a skip is not a failure: that client already had this
/// content, which is also why retrying is safe and pointless.
class AssignResultSheet extends StatelessWidget {
  const AssignResultSheet({
    super.key,
    required this.result,
    required this.clients,
  });

  final BulkAssignmentResult result;
  final List<TrainerClient> clients;

  static Future<void> show(
    BuildContext context, {
    required BulkAssignmentResult result,
    required List<TrainerClient> clients,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (_) => AssignResultSheet(result: result, clients: clients),
    );
  }

  String _nameOf(int clientId) {
    for (final client in clients) {
      if (client.userId == clientId) return client.displayName;
    }
    return '#$clientId';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final skipped = result.skippedClientIds;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: scheme.tertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.trainerAssignResultTitle(
                    result.assignedClientIds.length,
                    result.requestedCount,
                  ),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (skipped.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.trainerAssignSkippedTitle(skipped.length),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            for (final clientId in skipped)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.remove_circle_outline,
                        size: 15, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _nameOf(clientId),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              l10n.trainerAssignSkippedExplanation,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.okButton),
            ),
          ),
        ],
      ),
    );
  }
}
