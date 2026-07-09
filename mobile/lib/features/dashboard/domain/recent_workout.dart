/// A summarised workout session for the dashboard's "Recent workouts" list,
/// derived from the local workout-sessions cache.
class RecentWorkout {
  const RecentWorkout({
    required this.clientId,
    required this.startedAt,
    required this.setCount,
    required this.exerciseNames,
    this.finishedAt,
    this.activeCalories,
    this.categoryCode,
    this.templateName,
    this.rpe,
  });

  final String clientId;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int setCount;
  final List<String> exerciseNames;

  /// Snapshot of the template's name this session was started from, if any.
  final String? templateName;

  /// Dominant muscle-group code among this session's exercises (the group with
  /// the most exercises), used to colour the dashboard tile. Null when none of
  /// the exercises have a category.
  final String? categoryCode;

  /// Active energy burned (kcal), imported from Apple Health. Null when not paired.
  final double? activeCalories;

  /// Difficulty rating (1-10), null when the session hasn't been rated yet —
  /// drives the "rate this workout" nudge chip (see [needsRatingNudge]).
  final int? rpe;

  bool get inProgress => finishedAt == null;

  /// Recent (within [_nudgeWindow]), finished, and not yet rated — shows the
  /// "rate this workout" chip. Scoped to recent sessions so an old unrated
  /// history (e.g. from before this feature shipped) doesn't clutter the
  /// dashboard forever.
  bool get needsRatingNudge =>
      !inProgress &&
      rpe == null &&
      DateTime.now().difference(startedAt) <= _nudgeWindow;

  static const _nudgeWindow = Duration(days: 3);
}
