import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';

/// The "you are only looking" marker at the top of the pure data tabs
/// (frame C2, carried over from the web admin).
///
/// It works because of what is *not* next to it: those tabs carry no add, no
/// edit and no delete affordance at all. The badge names that absence so it
/// reads as deliberate rather than as a screen that failed to load its
/// buttons.
class ReadOnlyBadge extends StatelessWidget {
  const ReadOnlyBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = AppLocalizations.of(context)!;

    // Neutral on purpose: it is a fact about the screen, not a status, so it
    // takes no metric colour — the nested surface and the secondary text are
    // enough to be seen without competing with the data beside it.
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.s4),
      decoration: BoxDecoration(
        color: p.nested,
        borderRadius: AppRadius.pill,
        border: Border.all(color: p.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_outlined, size: 14, color: p.text2),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              l10n.trainerReadOnlyLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: p.text2),
            ),
          ),
        ],
      ),
    );
  }
}
