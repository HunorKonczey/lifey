import 'package:flutter/material.dart';

import '../../core/format/lifey_format.dart';
import '../../core/theme/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'ds/lifey_card.dart';

/// The trainer's comment on one of the user's meals, in full (LIF-144): the "Trainer comment" label, the text and when
/// it was written. The meal list shows only a line of it ([TrainerCommentLine]); this is the whole thing, on the meal
/// itself.
class TrainerCommentCard extends StatelessWidget {
  const TrainerCommentCard({super.key, required this.comment, this.writtenAt});

  final String comment;
  final DateTime? writtenAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    final at = writtenAt;

    return LifeyCard(
      key: const ValueKey('trainer-comment-card'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 21, color: p.role),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.trainerCommentLabel, style: t.bodySmall!.copyWith(fontWeight: FontWeight.w700, color: p.text)),
                const SizedBox(height: 2),
                Text(comment, style: t.bodyMedium!.copyWith(color: p.text)),
                if (at != null) ...[
                  const SizedBox(height: 4),
                  Text(LifeyFormat.of(context).shortDate(at.toLocal()), style: t.labelSmall!.copyWith(color: p.text2)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One or two lines of the trainer's comment under a meal in a list, so the user sees there is something to read
/// without opening the meal.
class TrainerCommentLine extends StatelessWidget {
  const TrainerCommentLine({super.key, required this.comment});

  final String comment;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.chat_bubble_outline_rounded, size: 14, color: p.role),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            comment,
            key: const ValueKey('trainer-comment-line'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.bodySmall!.copyWith(height: 1.4, fontWeight: FontWeight.w500, color: p.text),
          ),
        ),
      ],
    );
  }
}
