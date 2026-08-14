import 'package:flutter/material.dart';

import '../../features/workouts/domain/activity_type.dart';

/// Round icon badge for an activity type — one component, reused at every
/// size the design calls for (20/32/56 px on the quick-start tile, the
/// session list, the fajta-filter, notifications, and the watch — see
/// `docs/cardio/design/Lifey Cardio Design.dc.html` §1 "ActivityChip — egy
/// komponens, három méret"). [size] itself accepts any value; those three
/// are simply the sizes the design currently calls for, not a hard limit.
///
/// [activityType] is one of [kActivityTypes], or the `'STRENGTH'` sentinel
/// (see `activity_type.dart`) for the existing set-based workout.
class ActivityChip extends StatelessWidget {
  const ActivityChip({super.key, required this.activityType, this.size = 32});

  final String activityType;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = activityTypeColor(activityType, context);
    // Dark theme: 14% fill. Light theme: 16% — the design bumps it so the
    // chip doesn't wash out against a light card background.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: isDark ? 0.14 : 0.16),
      ),
      child: Center(
        child: Icon(
          activityTypeIcon(activityType),
          size: (size * 0.54).roundToDouble(),
          color: color,
        ),
      ),
    );
  }
}
