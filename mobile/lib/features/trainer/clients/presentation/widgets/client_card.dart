import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../shared/client_avatar.dart';
import '../../domain/compliance.dart';
import '../../domain/trainer_client.dart';
import 'compliance_badges.dart';
import 'weight_sparkline.dart';

/// One client, as a card rather than a table row (frame B1): monogram avatar,
/// name, how long ago they last logged anything, their compliance badges, and
/// a very faint weight sparkline along the bottom.
class ClientCard extends StatelessWidget {
  const ClientCard({
    super.key,
    required this.client,
    required this.now,
    this.onTap,
  });

  final TrainerClient client;

  /// Injected so the card's "days ago" and its badges are read off the same
  /// instant as the list's sort — and so tests don't depend on wall clock.
  final DateTime now;

  /// The client detail screen is T2's deliverable; until it exists there is
  /// nowhere honest for a tap to go, so the list passes null and the card
  /// renders without a tap affordance.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final flags = complianceFor(client, now: now);

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: AppRadius.cardAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClientAvatar(client: client),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _lastActiveLabel(l10n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (flags.needsAttention) ...[
                    const SizedBox(width: 8),
                    ComplianceBadges(flags: flags),
                  ],
                ],
              ),
              if (client.weightTrend.length >= 2) ...[
                const SizedBox(height: 8),
                WeightSparkline(points: client.weightTrend),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _lastActiveLabel(AppLocalizations l10n) {
    final lastActivityAt = client.lastActivityAt;
    if (lastActivityAt == null) return l10n.trainerClientNoActivityLabel;
    final days = _wholeDaysBetween(lastActivityAt, now);
    if (days == 0) return l10n.trainerClientActiveTodayLabel;
    return l10n.trainerClientActiveDaysAgoLabel(days);
  }
}

int _wholeDaysBetween(DateTime from, DateTime to) {
  final elapsedMs = to.millisecondsSinceEpoch - from.millisecondsSinceEpoch;
  if (elapsedMs < 0) return 0;
  return elapsedMs ~/ const Duration(days: 1).inMilliseconds;
}
