import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../../shared/widgets/ds/lifey_sheet.dart';
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
    return showLifeySheet<void>(
      context: context,
      title: AppLocalizations.of(context)!.trainerAssignButton,
      useRootNavigator: true,
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
    final p = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final skipped = result.skippedClientIds;

    // How many were assigned, then — only when someone was skipped — who, and
    // why. The frame (title, handle, safe area) is showLifeySheet's.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                l10n.trainerAssignResultTitle(result.assignedClientIds.length, result.requestedCount),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        if (skipped.isNotEmpty) ...[
          LifeyCard.nested(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.trainerAssignSkippedTitle(skipped.length), style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.s8),
                for (final clientId in skipped)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.remove_circle_outline_rounded, size: 16, color: p.text2),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(child: Text(_nameOf(clientId), style: theme.textTheme.bodyMedium)),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  l10n.trainerAssignSkippedExplanation,
                  style: theme.textTheme.labelSmall?.copyWith(color: p.text2),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
        ],
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.okButton),
          ),
        ),
      ],
    );
  }
}
