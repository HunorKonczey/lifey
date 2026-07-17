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
    this.rpe,
    this.feedbackNote,
    this.trainerComment,
    this.trainerCommentAt,
  });

  final String clientId;
  final int? id;

  /// Null for a trainer-scheduled session that hasn't been started yet — see
  /// [scheduledFor] and [isUpcoming].
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final List<SessionExercise> exercises;
  final List<ExerciseSet> sets;

  /// Active energy burned (kcal), enriched from a paired watch's workout
  /// summary (docs/watch/40-watch-app-plan.md) — the old manual "Import from
  /// Health" flow (doc 16) was removed 2026-07-16; this is the only source now.
  final double? activeCalories;

  /// Average heart rate (bpm) over the workout, enriched from a paired
  /// watch's workout summary — see [activeCalories].
  final double? averageHeartRate;

  /// The health-store workout id this session is paired with: a real
  /// `HKWorkout` UUID on iOS (the watch writes it directly), or a Health
  /// Connect record id on Android (the phone writes it itself once the watch
  /// summary arrives, since Health Connect writes must come from the phone —
  /// docs/watch/40-watch-app-plan.md §5.2). Non-null exactly when
  /// [enrichedFromWatch] is true.
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

  /// Difficulty rating (1-10, RPE-style — how hard the workout was, not a
  /// general mood rating), captured after finishing. Null until rated.
  final int? rpe;

  /// Optional free-text note captured alongside [rpe].
  final String? feedbackNote;

  /// The trainer's single editable comment on this session; null when
  /// uncommented. Trainer-owned — never sent in this app's create/update
  /// payload (see `WorkoutSessionRepository._payload`).
  final String? trainerComment;

  /// When [trainerComment] was last written; null when uncommented.
  final DateTime? trainerCommentAt;

  bool get inProgress => startedAt != null && finishedAt == null;

  /// Trainer-scheduled and not yet started — shows in the "Közelgő" section
  /// while [scheduledFor] is within the client's 7-day visibility window.
  bool get isUpcoming => startedAt == null && scheduledFor != null;

  /// True once a paired watch's workout summary has enriched this session
  /// with health-store metrics (docs/watch/40-watch-app-plan.md §12.4 B15) —
  /// drives the ⌚ badge on the session card. Named for the *source*
  /// (watch), not the *destination* store, since that differs by platform
  /// (HealthKit on iOS, Health Connect on Android — see [healthWorkoutId]).
  bool get enrichedFromWatch => healthWorkoutId != null;

  /// True once the user has rated this session's difficulty (see [rpe]).
  bool get isRated => rpe != null;
}
