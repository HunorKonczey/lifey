import 'activity_type.dart';

/// Cardio metrics for a CARDIO-kind session (docs/cardio/51-cardio-overview-plan.md
/// §3, docs/cardio/52-cardio-domain-backend-plan.md §2.2). Every field is
/// optional — a family fills in only the columns that apply to it.
///
/// Named `CardioMetrics`, not `CardioDetails`, to avoid colliding with the
/// Drift table class of that name
/// (`core/local_db/tables/workout_session_tables.dart`), which mirrors the
/// backend entity/table naming instead.
class CardioMetrics {
  const CardioMetrics({
    this.distanceMeters,
    this.elevationGainMeters,
    this.elevationLossMeters,
    this.maxAltitudeMeters,
    this.steps,
    this.avgCadence,
    this.maxCadence,
    this.best1kSeconds,
    this.best5kSeconds,
    this.best10kSeconds,
    this.avgWatts,
    this.maxWatts,
    this.resistanceLevel,
    this.deviceCalories,
    this.maxHeartRate,
    this.hrZone1Seconds,
    this.hrZone2Seconds,
    this.hrZone3Seconds,
    this.hrZone4Seconds,
    this.hrZone5Seconds,
    this.intensity,
    this.venue,
    this.gameFormat,
    this.scorePoints,
    this.scoreAssists,
    this.scoreRebounds,
    this.distanceSource,
    this.caloriesSource,
    this.routePolyline,
    this.routePointCount,
  });

  // DISTANCE + MACHINE
  final double? distanceMeters;
  final double? elevationGainMeters;
  final double? elevationLossMeters;
  final double? maxAltitudeMeters;
  final int? steps;

  /// Steps/min for running, rpm for the indoor bike.
  final double? avgCadence;
  final double? maxCadence;

  // Best efforts (docs/cardio/60 C6.1–C6.3) — the fastest *continuous*
  // 1/5/10 km inside the session, computed from the filtered trail at close
  // time by `best_effort_calculator.dart`, never the average pace scaled up
  // (docs/cardio/56 D-C3.8). Null means the distance doesn't exist in this
  // session (no trail, or shorter than the window) — never 0.
  final int? best1kSeconds;
  final int? best5kSeconds;
  final int? best10kSeconds;

  // MACHINE
  final double? avgWatts;
  final double? maxWatts;
  final int? resistanceLevel;

  /// The machine's own displayed calorie count — never auto-summed into
  /// daily active calories (docs/cardio/51-cardio-overview-plan.md Q4).
  final double? deviceCalories;

  // Shared physiological
  final double? maxHeartRate;
  final int? hrZone1Seconds;
  final int? hrZone2Seconds;
  final int? hrZone3Seconds;
  final int? hrZone4Seconds;
  final int? hrZone5Seconds;

  // GAME
  /// Subjective 1-5 intensity (docs/cardio/51-cardio-overview-plan.md §3.4).
  final int? intensity;

  /// `INDOOR` or `OUTDOOR` — drives GPS and the watch's activity locationType.
  final String? venue;

  /// Free-text format code, e.g. `5V5`, `SMALL_SIDED`, `PRACTICE`.
  final String? gameFormat;

  /// Basketball: points. Football: goals.
  final int? scorePoints;
  final int? scoreAssists;
  final int? scoreRebounds;

  // Provenance (docs/cardio/51-cardio-overview-plan.md R8) — a manual
  // override always wins over a measured value.
  final String? distanceSource;
  final String? caloriesSource;

  // Route (docs/cardio/54-cardio-gps-route-plan.md)
  /// Encoded, simplified polyline — raw GPS points never leave the phone.
  final String? routePolyline;
  final int? routePointCount;

  /// Mirrors `WorkoutSessionRepository._cardioPayload`'s key names 1:1 — used
  /// to decode the cardio block of a watch standalone-session wire payload
  /// (docs/cardio/55-cardio-watch-plan.md §5, W-1), the one other place a
  /// `CardioMetrics` needs to come from JSON rather than a Drift row.
  factory CardioMetrics.fromJson(Map<Object?, Object?> json) => CardioMetrics(
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
        elevationGainMeters: (json['elevationGainMeters'] as num?)?.toDouble(),
        elevationLossMeters: (json['elevationLossMeters'] as num?)?.toDouble(),
        maxAltitudeMeters: (json['maxAltitudeMeters'] as num?)?.toDouble(),
        steps: (json['steps'] as num?)?.toInt(),
        avgCadence: (json['avgCadence'] as num?)?.toDouble(),
        maxCadence: (json['maxCadence'] as num?)?.toDouble(),
        best1kSeconds: (json['best1kSeconds'] as num?)?.toInt(),
        best5kSeconds: (json['best5kSeconds'] as num?)?.toInt(),
        best10kSeconds: (json['best10kSeconds'] as num?)?.toInt(),
        avgWatts: (json['avgWatts'] as num?)?.toDouble(),
        maxWatts: (json['maxWatts'] as num?)?.toDouble(),
        resistanceLevel: (json['resistanceLevel'] as num?)?.toInt(),
        deviceCalories: (json['deviceCalories'] as num?)?.toDouble(),
        maxHeartRate: (json['maxHeartRate'] as num?)?.toDouble(),
        hrZone1Seconds: (json['hrZone1Seconds'] as num?)?.toInt(),
        hrZone2Seconds: (json['hrZone2Seconds'] as num?)?.toInt(),
        hrZone3Seconds: (json['hrZone3Seconds'] as num?)?.toInt(),
        hrZone4Seconds: (json['hrZone4Seconds'] as num?)?.toInt(),
        hrZone5Seconds: (json['hrZone5Seconds'] as num?)?.toInt(),
        intensity: (json['intensity'] as num?)?.toInt(),
        venue: json['venue'] as String?,
        gameFormat: json['gameFormat'] as String?,
        scorePoints: (json['scorePoints'] as num?)?.toInt(),
        scoreAssists: (json['scoreAssists'] as num?)?.toInt(),
        scoreRebounds: (json['scoreRebounds'] as num?)?.toInt(),
        distanceSource: json['distanceSource'] as String?,
        caloriesSource: json['caloriesSource'] as String?,
        routePolyline: json['routePolyline'] as String?,
        routePointCount: (json['routePointCount'] as num?)?.toInt(),
      );

  /// Fills in [fromWatch]'s watch-measured fields for whichever ones this
  /// session left null — never overwrites a value already here
  /// (docs/cardio/51-cardio-overview-plan.md R8: "a kézi érték mindig
  /// nyer"; docs/cardio/55-cardio-watch-plan.md §4.3: "csak akkor írják
  /// felül, ha a telefonnak nincs saját mérése"). Used by
  /// `WorkoutResumePrompt` to merge a `WatchWorkoutSummary.cardio` snapshot
  /// into an already-persisted phone-mastered session's own `cardio_details`
  /// once the watch's session closes.
  ///
  /// A plain `existing ?? fromWatch` per field — safe and correct even for
  /// fields no sender populates yet (heart-rate zones: no watch build
  /// computes these today, since the zone *boundaries* themselves aren't a
  /// concept this app defines anywhere yet, watch-side or otherwise — a
  /// separate, unscoped product decision, not something to invent here).
  /// `fromWatch` simply carries `null` for those, so the merge is a no-op
  /// for them until a real sender exists — the same "receiver ready before
  /// sender" shape this whole cardio watch integration has followed
  /// throughout (docs/cardio/55-cardio-watch-plan.md D-C5.4).
  ///
  /// [distanceSource] is the one field with real provenance semantics: it's
  /// only ever set to `'DEVICE'` when the watch's distance is what actually
  /// *filled* a previously-empty value — a manual/measured distance already
  /// on this session keeps its own source tag untouched, distance and all.
  /// Whether *any* of the five zone columns is filled in here — the test the
  /// zone block's all-or-nothing merge turns on.
  bool get _hasZoneData =>
      hrZone1Seconds != null ||
      hrZone2Seconds != null ||
      hrZone3Seconds != null ||
      hrZone4Seconds != null ||
      hrZone5Seconds != null;

  CardioMetrics mergedWithWatchMeasurement(CardioMetrics fromWatch) => CardioMetrics(
        distanceMeters: distanceMeters ?? fromWatch.distanceMeters,
        distanceSource: distanceMeters != null || fromWatch.distanceMeters == null
            ? distanceSource
            : 'DEVICE',
        elevationGainMeters: elevationGainMeters ?? fromWatch.elevationGainMeters,
        elevationLossMeters: elevationLossMeters ?? fromWatch.elevationLossMeters,
        maxAltitudeMeters: maxAltitudeMeters ?? fromWatch.maxAltitudeMeters,
        steps: steps ?? fromWatch.steps,
        avgCadence: avgCadence ?? fromWatch.avgCadence,
        maxCadence: maxCadence ?? fromWatch.maxCadence,
        best1kSeconds: best1kSeconds ?? fromWatch.best1kSeconds,
        best5kSeconds: best5kSeconds ?? fromWatch.best5kSeconds,
        best10kSeconds: best10kSeconds ?? fromWatch.best10kSeconds,
        avgWatts: avgWatts ?? fromWatch.avgWatts,
        maxWatts: maxWatts ?? fromWatch.maxWatts,
        resistanceLevel: resistanceLevel ?? fromWatch.resistanceLevel,
        deviceCalories: deviceCalories ?? fromWatch.deviceCalories,
        maxHeartRate: maxHeartRate ?? fromWatch.maxHeartRate,
        // The zone set moves as **one block**, not field by field (C9.1's
        // guard, docs/cardio/60 §9): whoever already has zone data here keeps
        // all five columns. Merging them individually would let a phone-
        // measured Z1 sit next to a watch-measured Z2-Z5 from a different
        // measurement of the same session, and the five would then total more
        // time than the session lasted — a bar wider than its own track and a
        // "112% in zone" reading, with nothing in the data to say which half
        // was wrong.
        hrZone1Seconds: _hasZoneData ? hrZone1Seconds : fromWatch.hrZone1Seconds,
        hrZone2Seconds: _hasZoneData ? hrZone2Seconds : fromWatch.hrZone2Seconds,
        hrZone3Seconds: _hasZoneData ? hrZone3Seconds : fromWatch.hrZone3Seconds,
        hrZone4Seconds: _hasZoneData ? hrZone4Seconds : fromWatch.hrZone4Seconds,
        hrZone5Seconds: _hasZoneData ? hrZone5Seconds : fromWatch.hrZone5Seconds,
        intensity: intensity ?? fromWatch.intensity,
        venue: venue ?? fromWatch.venue,
        gameFormat: gameFormat ?? fromWatch.gameFormat,
        scorePoints: scorePoints ?? fromWatch.scorePoints,
        scoreAssists: scoreAssists ?? fromWatch.scoreAssists,
        scoreRebounds: scoreRebounds ?? fromWatch.scoreRebounds,
        caloriesSource: caloriesSource ?? fromWatch.caloriesSource,
        routePolyline: routePolyline ?? fromWatch.routePolyline,
        routePointCount: routePointCount ?? fromWatch.routePointCount,
      );
}

/// One per-km/lap split for a DISTANCE-family cardio session
/// (docs/cardio/52-cardio-domain-backend-plan.md §2.3) — computed
/// client-side at close time, never derived server-side.
class CardioSplit {
  const CardioSplit({
    required this.splitIndex,
    required this.distanceMeters,
    required this.durationSeconds,
    this.elevationDeltaM,
    this.avgHeartRate,
  });

  /// 0-based position within the session's split list.
  final int splitIndex;

  /// Usually exactly 1000 (one km); the last split of a run is shorter.
  final double distanceMeters;
  final int durationSeconds;

  /// Net elevation change over the split; null when no altitude data was available.
  final double? elevationDeltaM;
  final double? avgHeartRate;
}

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
    this.sessionKind = 'STRENGTH',
    this.activityType,
    this.movingSeconds,
    this.movingSinceEpochMs,
    this.cardio,
    this.splits = const [],
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

  /// `'STRENGTH'` or `'CARDIO'` (docs/cardio/51-cardio-overview-plan.md
  /// D-C.1) — a plain `String`, not a Dart enum: an unrecognized value from
  /// a future server build must fall back gracefully (see
  /// `activity_type.dart`'s doc), not throw a parse error. Never null —
  /// defaults to `'STRENGTH'` for every session that predates cardio.
  final String sessionKind;

  /// Non-null exactly when [sessionKind] is `'CARDIO'` — one of
  /// [kActivityTypes]. See `activity_type.dart`.
  final String? activityType;

  /// Time actually spent moving, in seconds — the wall-clock span minus
  /// pauses and auto-pause gaps (docs/cardio/56-cardio-statistics-plan.md
  /// D-C3.3). Null for a STRENGTH session, where [effectiveDuration] already
  /// is the wall-clock span. While [isCardioRunning], this is the total
  /// *before* the current running interval — see [movingSinceEpochMs] and
  /// `liveMovingSeconds` (docs/cardio/59-cardio-implementation-plan.md C2.1).
  final int? movingSeconds;

  /// Epoch-ms checkpoint for a **live** `CardioSessionScreen` — non-null
  /// exactly while the session is actively moving (not paused, not
  /// finished). Client-only, never synced — see the Drift column doc
  /// (`core/local_db/tables/workout_session_tables.dart`) for the full
  /// rationale. Use `liveMovingSeconds` to read the current total; don't add
  /// this to [movingSeconds] directly, since that skips the "already
  /// finished" / "still absent" guards the helper applies.
  final int? movingSinceEpochMs;

  /// Cardio metrics; non-null only when [isCardio] and at least one metric
  /// was recorded.
  final CardioMetrics? cardio;

  /// Per-km/lap splits; empty unless [isCardio] and splits were recorded.
  final List<CardioSplit> splits;

  bool get inProgress => startedAt != null && finishedAt == null;

  /// True while a live `CardioSessionScreen` has this session actively
  /// moving — i.e. not paused, and not finished. See [movingSinceEpochMs].
  bool get isCardioRunning => inProgress && movingSinceEpochMs != null;

  /// True for a cardio/sport session — see [sessionKind].
  bool get isCardio => sessionKind == 'CARDIO';

  /// The metric/UI family [activityType] belongs to, or null for a STRENGTH
  /// session (or the rare case of a cardio session with no activityType at
  /// all, which the server rejects but a not-yet-synced local draft could
  /// theoretically pass through).
  ActivityFamily? get family => activityType == null ? null : activityFamilyOf(activityType!);

  /// The training time statistics should count: [movingSeconds] when tracked
  /// (every cardio session with a recorded moving time), else the wall-clock
  /// span between [startedAt] and [finishedAt] (every STRENGTH session, and
  /// a cardio session that never tracked moving time separately). Null while
  /// still running or not yet started.
  Duration? get effectiveDuration {
    if (movingSeconds != null) return Duration(seconds: movingSeconds!);
    if (startedAt != null && finishedAt != null) {
      return finishedAt!.difference(startedAt!);
    }
    return null;
  }

  /// Current moving seconds for a **live** cardio session, folding in the
  /// still-ticking interval when [isCardioRunning] — read this instead of
  /// [movingSeconds] directly whenever the number needs to be accurate to
  /// the second (every `CardioSessionScreen` ticker frame). When not
  /// currently running (paused, finished, or never started), this is just
  /// [movingSeconds] (or 0 if that's also null — a session that hasn't
  /// moved yet).
  int liveMovingSeconds(DateTime now) {
    final base = movingSeconds ?? 0;
    final since = movingSinceEpochMs;
    if (since == null) return base;
    return base + now.difference(DateTime.fromMillisecondsSinceEpoch(since)).inSeconds;
  }

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
