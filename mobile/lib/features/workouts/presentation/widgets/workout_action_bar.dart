import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import 'music_sticky_button.dart';

/// Height of the floating bar and of both of its buttons.
const double kWorkoutActionBarHeight = 60;

/// The music button and "⚑ Finish workout" as one floating bar at the bottom of
/// the live strength screen, where the navigation bar sits everywhere else —
/// under the thumb, above the safe area (docs/redesign/77-mobile-redesign-plan.md
/// R3.6; canvas Lifey 3 › 3.2 "Zene és befejezés egy sávban"). Finish carries
/// the flag icon so it is never mistaken for a set's check.
class WorkoutActionBar extends StatelessWidget {
  const WorkoutActionBar({super.key, required this.saving, required this.onFinish});

  /// A save is in flight: Finish shows a spinner and does nothing.
  final bool saving;
  final VoidCallback onFinish;

  /// Space the list must leave under its last item so nothing hides behind
  /// the bar: its height, the gap under it and the bottom safe area.
  static double reservedHeight(double safeBottom) =>
      _fadeHeight + kWorkoutActionBarHeight + AppSpacing.s16 + AppSpacing.s16 + safeBottom;

  /// The fade above the bar that lets the list disappear under it.
  static const double _fadeHeight = AppSpacing.s24;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    final bg = context.palette.bg;
    return DecoratedBox(
      // The list scrolls under the bar: fade it out instead of letting rows
      // show between and around the buttons.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg.withValues(alpha: 0), bg.withValues(alpha: 0.94)],
          stops: const [0, 0.3],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.screen - AppSpacing.s4, _fadeHeight, AppSpacing.screen - AppSpacing.s4, safeBottom + AppSpacing.s16),
        child: Row(
        children: [
          const MusicStickyButton(),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: SizedBox(
              height: kWorkoutActionBarHeight,
              child: FilledButton.icon(
                onPressed: saving ? null : onFinish,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
                  textStyle: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w800),
                  elevation: 0,
                ),
                icon: saving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary.withValues(alpha: 0.7)),
                      )
                    : const Icon(Icons.flag_rounded, size: 22),
                label: Text(l10n.finishWorkoutButton),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
