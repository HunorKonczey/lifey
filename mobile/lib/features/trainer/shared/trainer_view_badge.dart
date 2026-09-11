import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';

/// The "you are in the trainer view" chip that sits next to the app-bar title
/// on every trainer screen (docs/chat/43-trainer-mobile-v2-design-prompt.md,
/// frame A1 — the mobile answer to the web admin's permanent EDZŐ chip).
///
/// `tertiary` on purpose: it is the accent the whole trainer shell uses
/// against the client shell's `primary`, so the two read as siblings rather
/// than as one app in two modes.
class TrainerViewBadge extends StatelessWidget {
  const TrainerViewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fitness_center, size: 12, color: scheme.onTertiaryContainer),
          const SizedBox(width: 4),
          Text(
            l10n.trainerViewBadgeLabel,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: scheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
