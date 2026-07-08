/// A single set within a logged session (response side).
class ExerciseSet {
  const ExerciseSet({
    required this.exerciseClientId,
    required this.exerciseName,
    required this.reps,
    required this.weight,
    required this.performedAt,
  });

  final String exerciseClientId;
  final String exerciseName;
  final int reps;
  final double weight;
  final DateTime performedAt;
}

/// An exercise planned for a session (a quick-add default) — e.g. copied in
/// from a template at creation time — independent of how many [ExerciseSet]s
/// have actually been logged for it.
class SessionExercise {
  const SessionExercise({
    required this.exerciseClientId,
    required this.exerciseName,
    this.targetSets,
  });

  final String exerciseClientId;
  final String exerciseName;
  final int? targetSets;
}

/// A logged workout session (`/workout-sessions`).
class WorkoutSession {
  const WorkoutSession({
    required this.clientId,
    required this.exercises,
    required this.sets,
    this.id,
    this.startedAt,
    this.finishedAt,
    this.activeCalories,
    this.averageHeartRate,
    this.healthWorkoutId,
    this.templateClientId,
    this.templateName,
    this.scheduledFor,
    this.scheduledTime,
    this.scheduleId,
  });

  final String clientId;
  final int? id;

  /// Null for a trainer-scheduled session that hasn't been started yet — see
  /// [scheduledFor] and [isUpcoming].
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final List<SessionExercise> exercises;
  final List<ExerciseSet> sets;

  /// Active energy burned (kcal), imported from Apple Health.
  final double? activeCalories;

  /// Average heart rate (bpm) over the workout, imported from Apple Health.
  final double? averageHeartRate;

  /// HKWorkout UUID this session was paired with, if imported from Apple Health.
  final String? healthWorkoutId;

  /// clientId of the template this session was started from, null when
  /// started as an empty workout (or predates this field).
  final String? templateClientId;

  /// Snapshot of the template's name at the time this session was started,
  /// null when started as an empty workout (or predates this field).
  final String? templateName;

  /// Calendar day the trainer scheduled this session for; null for a normal
  /// (client-started) session — docs/personal_trainer/08-utemezett-edzesek-koncepcio.md.
  final DateTime? scheduledFor;

  /// Optional wall-clock time ("HH:mm") the trainer scheduled this for;
  /// display/ordering only.
  final String? scheduledTime;

  /// The originating schedule's server id, if this session was materialized
  /// from one.
  final int? scheduleId;

  bool get inProgress => startedAt != null && finishedAt == null;

  /// Trainer-scheduled and not yet started — shows in the "Közelgő" section
  /// while [scheduledFor] is within the client's 7-day visibility window.
  bool get isUpcoming => startedAt == null && scheduledFor != null;

  bool get fromAppleHealth => healthWorkoutId != null;
}
