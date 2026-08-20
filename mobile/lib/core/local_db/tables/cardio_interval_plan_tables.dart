import 'package:drift/drift.dart';

/// A reusable interval plan for the indoor bike — "4×4 perc kemény / 3 perc
/// könnyű" (docs/cardio/60 D-C7.1, backend `cardio_interval_plans`).
///
/// The plan is a blueprint only: running it writes INTERVAL splits onto the
/// session ([CardioSplits]), which carry their own durations and intensities.
/// Nothing points from a session back to a plan, so deleting a plan never
/// touches the sessions run with it.
@DataClassName('CardioIntervalPlanRow')
class CardioIntervalPlans extends Table {
  @override
  String get tableName => 'cardio_interval_plans';

  TextColumn get clientId => text()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {clientId};
}

/// One item of a plan: either a `STEP` (a duration at a target intensity) or
/// a `REPEAT` block holding steps — docs/cardio/61 §3 M37, "4× (4:00 kemény
/// + 3:00 könnyű)". Nesting is exactly one level deep: a `REPEAT` always has
/// a null [parentStepClientId].
///
/// No `serverId` here, unlike most child tables: the backend never exposes
/// step ids at all (a plan's steps arrive nested inside the plan and are
/// replaced wholesale on every write), so a local id column would only ever
/// hold null.
@DataClassName('CardioIntervalStepRow')
class CardioIntervalSteps extends Table {
  @override
  String get tableName => 'cardio_interval_steps';

  TextColumn get clientId => text()();
  TextColumn get planClientId => text().references(CardioIntervalPlans, #clientId)();

  /// The `REPEAT` block this step sits in; null for a top-level item.
  TextColumn get parentStepClientId => text().nullable()();

  /// 0-based position among its siblings (within the same parent), not
  /// within the plan.
  IntColumn get stepIndex => integer()();

  /// `STEP` or `REPEAT` — the backend's `IntervalStepType` codes.
  TextColumn get stepType => text()();

  /// "Bemelegítés" — optional; without it the intensity label carries the meaning.
  TextColumn get name => text().nullable()();

  /// `EASY` | `MODERATE` | `HARD`, set exactly for a `STEP`.
  TextColumn get intensity => text().nullable()();

  /// Set exactly for a `STEP`.
  IntColumn get durationSeconds => integer().nullable()();

  /// Set exactly for a `REPEAT`: how many times its children run.
  IntColumn get repeatCount => integer().nullable()();

  @override
  Set<Column> get primaryKey => {clientId};
}
