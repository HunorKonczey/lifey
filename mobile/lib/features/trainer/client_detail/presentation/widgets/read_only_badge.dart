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
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: AppRadius.pill,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_outlined, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            l10n.trainerReadOnlyLabel,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
