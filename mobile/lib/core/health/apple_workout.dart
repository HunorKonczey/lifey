/// A finished Apple Health (HealthKit) workout, read on demand via a
/// foreground query (see [HealthService.recentStrengthWorkouts]).
///
/// HealthKit only exposes a workout once it has been *saved/finished* — there
/// is no live "in progress" signal for workouts another app owns (see
/// docs/16-apple-health-integration-plan.md §1) — so this always describes an
/// already-completed workout. It is read on demand by a foreground query when
/// the user taps "Import from Apple Health" on the active workout.
class AppleWorkout {
  const AppleWorkout({
    required this.uuid,
    required this.startDate,
    required this.endDate,
    this.activeCalories,
    this.averageHeartRate,
  });

  /// The HKWorkout UUID — stored on the paired session as `healthWorkoutId`,
  /// which both marks it as imported and guards against importing twice.
  final String uuid;
  final DateTime startDate;
  final DateTime endDate;

  /// Active energy burned (kcal) — null if HealthKit didn't record it.
  final double? activeCalories;

  /// Mean heart rate (bpm) over [startDate]–[endDate] — null if no samples.
  final double? averageHeartRate;
}
