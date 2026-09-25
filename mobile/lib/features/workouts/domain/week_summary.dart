import '../../streaks/domain/weekly_recap.dart';
import 'activity_type.dart';
import 'workout_session.dart';

/// The three numbers over the Sessions list: workouts, minutes and distance
/// of the current Monday–Sunday week (docs/redesign/77-mobile-redesign-plan.md
/// R3.1). Counted by the rules of the weekly recap — the two must agree — so
/// a session counts when it started this week (finished or not), minutes are
/// the finished sessions' effective durations, and distance is DISTANCE and
/// MACHINE cardio only (`stat_chart_data.dart`'s cardio distance metric).
class WeekSummary {
  const WeekSummary({required this.workouts, required this.minutes, required this.distanceMeters});

  final int workouts;
  final int minutes;
  final double distanceMeters;

  bool get isEmpty => workouts == 0;
}

/// The week summary of [sessions] for the week containing [now].
WeekSummary computeWeekSummary(List<WorkoutSession> sessions, DateTime now) {
  final weekStart = WeeklyRecap.weekStartFor(now);
  final nextWeek = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
  var workouts = 0;
  var minutes = 0;
  var distance = 0.0;
  for (final session in sessions) {
    final started = session.startedAt;
    if (session.isUpcoming || started == null) continue;
    final local = started.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (day.isBefore(weekStart) || !day.isBefore(nextWeek)) continue;
    workouts++;
    final duration = session.effectiveDuration;
    if (duration != null) minutes += duration.inMinutes;
    final meters = session.cardio?.distanceMeters;
    if (session.isCardio &&
        meters != null &&
        (session.family == ActivityFamily.distance || session.family == ActivityFamily.machine)) {
      distance += meters;
    }
  }
  return WeekSummary(workouts: workouts, minutes: minutes, distanceMeters: distance);
}
