import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/entitlements/sponsorship_notice.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// The one notice a client gets when their trainer's sponsored Pro ends
/// (`69` §12.1, built in `72` Prompt 10).
///
/// Deliberately the quietest possible surface: a dismissible dashboard card,
/// no push, no modal, no paywall redirect. Losing sight of history looks
/// exactly like losing the data, so the reassurance ("az adataid megvannak")
/// is the line that matters, not the upsell — there is no CTA here at all.
/// The paywall becomes reachable again the moment the sponsorship ends
/// (`69` §12.1 rule 1), from its normal entry points.
class SponsorshipEndedCard extends ConsumerWidget {
  const SponsorshipEndedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(sponsorshipNoticeProvider).value ?? false;
    if (!pending) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: scheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sponsorshipEndedCardTitle,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.sponsorshipEndedCardMessage,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => ref.read(sponsorshipNoticeProvider.notifier).dismiss(),
            icon: const Icon(Icons.close, size: 18),
            tooltip: l10n.sponsorshipEndedCardDismissTooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
