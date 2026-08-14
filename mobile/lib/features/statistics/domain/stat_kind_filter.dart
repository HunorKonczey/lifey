/// Narrows which sessions count toward the "edzés jellegű" (workout-like)
/// `StatMetric`s — `workoutCount`/`workoutMinutes`/`activeCalories`
/// (docs/cardio/56-cardio-statistics-plan.md D-C3.4). Never a fourth,
/// finer-grained per-`kActivityTypes` option — that's `SessionsTab`'s own
/// list filter, a different screen with a different job; this one only
/// answers "strength or cardio", matching the design's plain 3-way
/// SegmentedButton (M21/M22).
///
/// Doesn't affect nutrition/water/weight/steps metrics — those have nothing
/// to do with workout kind. The six cardio-only metrics (distance, moving
/// minutes, elevation, pace, max heart rate, cardio session count) are
/// narrowed the same way in effect — they only ever include cardio sessions
/// regardless of this filter, so under [strength] they simply have nothing
/// to show.
enum StatKindFilter { all, strength, cardio }
