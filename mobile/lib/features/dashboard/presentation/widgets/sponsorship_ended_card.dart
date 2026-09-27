import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/entitlements/sponsorship_notice.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/notice_card.dart';

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

    // Clay: it comes from the trainer. Quiet on purpose — no CTA (see above).
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: NoticeCard(
        icon: Icons.info_outline_rounded,
        accent: context.palette.role,
        title: l10n.sponsorshipEndedCardTitle,
        body: l10n.sponsorshipEndedCardMessage,
        onDismiss: () => ref.read(sponsorshipNoticeProvider.notifier).dismiss(),
        dismissTooltip: l10n.sponsorshipEndedCardDismissTooltip,
      ),
    );
  }
}
