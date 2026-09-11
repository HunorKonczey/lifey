import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../domain/compliance.dart';

/// The compliance flags of one client, as icon + short number chips
/// (frame B1: "ikon + rövid szám, nem hosszú szöveg").
///
/// Each chip carries the full sentence as its semantics label, so a screen
/// reader gets "No log for 5 days" where the eye gets a clock and "5d".
/// Renders nothing when the client is fully compliant.
class ComplianceBadges extends StatelessWidget {
  const ComplianceBadges({super.key, required this.flags});

  final ComplianceFlags flags;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (flags.inactive)
          _Badge(
            icon: Icons.schedule,
            text: l10n.trainerComplianceDaysShortLabel(flags.daysSinceLastLog),
            semanticsLabel:
                l10n.trainerComplianceInactiveSemanticsLabel(flags.daysSinceLastLog),
            background: scheme.errorContainer,
            foreground: scheme.onErrorContainer,
          ),
        if (flags.hasMissedWorkouts)
          _Badge(
            icon: Icons.fitness_center,
            text: l10n.trainerComplianceMissedShortLabel(flags.missedWorkouts),
            semanticsLabel:
                l10n.trainerComplianceMissedSemanticsLabel(flags.missedWorkouts),
            background: scheme.errorContainer,
            foreground: scheme.onErrorContainer,
          ),
        if (flags.weightStale)
          _Badge(
            icon: Icons.monitor_weight_outlined,
            text: l10n.trainerComplianceDaysShortLabel(flags.daysSinceWeight),
            semanticsLabel:
                l10n.trainerComplianceWeightStaleSemanticsLabel(flags.daysSinceWeight),
            // A missed weigh-in is a nudge, not an alarm — it gets the
            // quieter surface so the two error-coloured chips keep meaning
            // something when they appear next to it.
            background: scheme.surfaceContainerHighest,
            foreground: scheme.onSurfaceVariant,
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.text,
    required this.semanticsLabel,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final String semanticsLabel;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: background, borderRadius: AppRadius.pill),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
