import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';
import '../../../l10n/app_localizations.dart';

/// The "you are in the trainer view" mark that sits above the title of every
/// trainer screen (canvas Lifey 6: "TRAINER" in clay on a clay tint).
///
/// The trainer shell is the client app's own family — the same olive, chips
/// and cards — and this mark is the only thing that says which role you are
/// in: the clay `palette.role`, the existing second colour, never a second
/// green.
class TrainerViewBadge extends StatelessWidget {
  const TrainerViewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.palette.role;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s4),
      decoration: BoxDecoration(
        color: role.withValues(alpha: dark ? 0.16 : 0.12),
        borderRadius: AppRadius.controlAll,
      ),
      child: Text(
        l10n.trainerViewBadgeLabel.toUpperCase(),
        style: AppType.sectionLabel(color: role).copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}
