/// A finished workout read from the platform's health store on demand (see
/// [HealthService.recentStrengthWorkouts]) — Apple Health (HealthKit) on iOS,
/// Google Health Connect on Android.
///
/// Neither platform exposes a live "in progress" signal for a workout another
/// app owns (see docs/16-apple-health-integration-plan.md §1) — so this
/// always describes an already-completed workout, read on demand by a
/// foreground query when the user taps "Import from Health" on the active
/// workout.
class HealthWorkout {
  const HealthWorkout({
    required this.uuid,
    required this.startDate,
    required this.endDate,
    this.activeCalories,
    this.averageHeartRate,
  });

  /// The workout's platform id (HKWorkout UUID on iOS, Health Connect record
  /// id on Android) — stored on the paired session as `healthWorkoutId`,
  /// which both marks it as imported and guards against importing twice.
  final String uuid;
  final DateTime startDate;
  final DateTime endDate;

  /// Active energy burned (kcal) — null if not recorded.
  final double? activeCalories;

  /// Mean heart rate (bpm) over [startDate]–[endDate] — null if no samples.
  final double? averageHeartRate;
}
