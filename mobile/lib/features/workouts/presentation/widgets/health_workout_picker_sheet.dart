import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/health/health_workout.dart';
import '../../../../l10n/app_localizations.dart';

/// Bottom sheet listing recent, not-yet-paired Health workouts so the user
/// can manually pick one to import into an already-closed session (the
/// automatic same-session match at Finish time only looks at the last day
/// and requires the workout to have already ended).
///
/// Pops with the picked [HealthWorkout], or null if dismissed.
class HealthWorkoutPickerSheet extends StatelessWidget {
  const HealthWorkoutPickerSheet({super.key, required this.candidates});

  final List<HealthWorkout> candidates;

  static final _label = DateFormat('EEE, MMM d · HH:mm');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.pickHealthWorkoutTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l10n.noRecentHealthWorkoutMessage,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final workout = candidates[i];
                    return ListTile(
                      leading: Icon(Icons.fitness_center_rounded,
                          color: scheme.primary),
                      title: Text(_label.format(workout.startDate.toLocal())),
                      subtitle: Text(l10n.healthStatsLine(
                        workout.activeCalories?.round().toString() ?? '–',
                        workout.averageHeartRate?.round().toString() ?? '–',
                      )),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pop(workout),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
