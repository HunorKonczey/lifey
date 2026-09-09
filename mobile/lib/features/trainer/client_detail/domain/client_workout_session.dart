import '../../clients/domain/trainer_client.dart' show parseTrainerTimestamp;

/// One of the client's finished sessions, as `WorkoutSessionResponse` gives
/// it (docs/chat/41-trainer-mobile-v2-plan.md T3).
///
/// A deliberately partial read of a large DTO: the trainer's session view
/// answers "what did they do, how hard was it, and what did they say about
/// it". The cardio metrics beyond distance, the HR zones, the splits and the
/// route are not on that list, so they are not parsed — the client's own
/// summary screen is where those belong.
class ClientWorkoutSession {
  const ClientWorkoutSession({
    required this.id,
    required this.startedAt,
    this.finishedAt,
    this.templateName,
    this.sessionKind = 'STRENGTH',
    this.activityType,
    this.movingSeconds,
    this.distanceMeters,
    this.exercises = const [],
    this.sets = const [],
    this.rpe,
    this.feedbackNote,
    this.trainerComment,
    this.trainerCommentAt,
  });

  final int id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String? templateName;

  /// `'STRENGTH'` or `'CARDIO'`, kept as a string for the same reason the
  /// client-side model does: an unrecognised value from a newer backend must
  /// not crash the parse.
  final String sessionKind;
  final String? activityType;
  final int? movingSeconds;
  final double? distanceMeters;

  final List<ClientSessionExercise> exercises;
  final List<ClientSessionSet> sets;

  /// The client's own post-workout rating (1–10) and note — the half of the
  /// feedback loop the trainer is answering (docs/31).
  final int? rpe;
  final String? feedbackNote;

  /// The trainer's single editable comment, and when it was last written.
  final String? trainerComment;
  final DateTime? trainerCommentAt;

  bool get isCardio => sessionKind == 'CARDIO';
  bool get hasTrainerComment => (trainerComment ?? '').isNotEmpty;

  /// Wall-clock length. Null while a session is still running — the trainer
  /// only ever sees finished ones, but the field is nullable on the wire.
  Duration? get duration => finishedAt?.difference(startedAt);

  /// Distinct exercises actually performed, falling back to the planned list
  /// for a session whose sets were never filled in.
  int get exerciseCount {
    if (sets.isNotEmpty) return sets.map((set) => set.exerciseId).toSet().length;
    return exercises.length;
  }

  /// The sets of one exercise, in the order they were performed.
  List<ClientSessionSet> setsOf(int exerciseId) =>
      sets.where((set) => set.exerciseId == exerciseId).toList();

  /// Every exercise that has either a plan or at least one logged set, named
  /// once each and in the session's own order.
  List<ClientSessionExercise> get performedExercises {
    final byId = <int, ClientSessionExercise>{
      for (final exercise in exercises) exercise.exerciseId: exercise,
    };
    for (final set in sets) {
      byId.putIfAbsent(
        set.exerciseId,
        () => ClientSessionExercise(
          exerciseId: set.exerciseId,
          exerciseName: set.exerciseName,
        ),
      );
    }
    return byId.values.toList();
  }

  factory ClientWorkoutSession.fromJson(Map<String, dynamic> json) {
    final cardio = json['cardio'] as Map<String, dynamic>?;
    return ClientWorkoutSession(
      id: (json['id'] as num).toInt(),
      startedAt: parseTrainerTimestamp(json['startedAt'] as String),
      finishedAt: json['finishedAt'] == null
          ? null
          : parseTrainerTimestamp(json['finishedAt'] as String),
      templateName: json['templateName'] as String?,
      sessionKind: json['sessionKind'] as String? ?? 'STRENGTH',
      activityType: json['activityType'] as String?,
      movingSeconds: (json['movingSeconds'] as num?)?.toInt(),
      distanceMeters: (cardio?['distanceMeters'] as num?)?.toDouble(),
      exercises: ((json['exercises'] as List<dynamic>?) ?? const [])
          .map((e) => ClientSessionExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
      sets: ((json['sets'] as List<dynamic>?) ?? const [])
          .map((e) => ClientSessionSet.fromJson(e as Map<String, dynamic>))
          .toList(),
      rpe: (json['rpe'] as num?)?.toInt(),
      feedbackNote: json['feedbackNote'] as String?,
      trainerComment: json['trainerComment'] as String?,
      trainerCommentAt: json['trainerCommentAt'] == null
          ? null
          : parseTrainerTimestamp(json['trainerCommentAt'] as String),
    );
  }
}

/// A planned exercise within a session (`ExerciseSummary`).
class ClientSessionExercise {
  const ClientSessionExercise({
    required this.exerciseId,
    required this.exerciseName,
    this.targetSets,
  });

  final int exerciseId;
  final String exerciseName;
  final int? targetSets;

  factory ClientSessionExercise.fromJson(Map<String, dynamic> json) {
    return ClientSessionExercise(
      exerciseId: (json['exerciseId'] as num).toInt(),
      exerciseName: json['exerciseName'] as String? ?? '',
      targetSets: (json['targetSets'] as num?)?.toInt(),
    );
  }
}

/// One logged set (`ExerciseSetResponse`).
class ClientSessionSet {
  const ClientSessionSet({
    required this.exerciseId,
    required this.exerciseName,
    this.reps,
    this.weight,
  });

  final int exerciseId;
  final String exerciseName;
  final int? reps;
  final double? weight;

  factory ClientSessionSet.fromJson(Map<String, dynamic> json) {
    return ClientSessionSet(
      exerciseId: (json['exerciseId'] as num).toInt(),
      exerciseName: json['exerciseName'] as String? ?? '',
      reps: (json['reps'] as num?)?.toInt(),
      weight: (json['weight'] as num?)?.toDouble(),
    );
  }
}

/// One page of `GET .../workout-sessions`, which is a Spring `Page`.
///
/// Only `content` and `last` are read: the trainer's list appends until the
/// backend says there is nothing more, and a total count it never shows would
/// only be one more thing that could disagree with the rows on screen.
class ClientSessionPage {
  const ClientSessionPage({required this.sessions, required this.isLast});

  final List<ClientWorkoutSession> sessions;
  final bool isLast;

  factory ClientSessionPage.fromJson(Map<String, dynamic> json) {
    return ClientSessionPage(
      sessions: ((json['content'] as List<dynamic>?) ?? const [])
          .map((e) => ClientWorkoutSession.fromJson(e as Map<String, dynamic>))
          .toList(),
      isLast: json['last'] as bool? ?? true,
    );
  }
}
