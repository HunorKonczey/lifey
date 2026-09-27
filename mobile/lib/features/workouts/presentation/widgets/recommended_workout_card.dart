import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/notice_card.dart';
import '../../domain/workout_template.dart';

/// Card suggesting the next workout based on the user's repeating template
/// rotation — tinted brand olive, so it reads as an invitation rather than
/// "just another item" in the list. Tapping it starts a session from
/// [template].
class RecommendedWorkoutCard extends StatelessWidget {
  const RecommendedWorkoutCard({
    super.key,
    required this.template,
    required this.onTap,
  });

  final WorkoutTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: NoticeCard(
        icon: Icons.bolt_rounded,
        overline: l10n.recommendedWorkoutLabel,
        title: template.name,
        onTap: onTap,
        trailing: Icon(Icons.play_circle_fill_rounded,
            size: 30, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
