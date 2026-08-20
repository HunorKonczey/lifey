/// Whether a plan item is a section or the repeat block that holds sections
/// (docs/cardio/61 §3 M37). The wire codes mirror the backend's
/// `IntervalStepType`.
enum IntervalStepType {
  step('STEP'),
  repeat('REPEAT');

  const IntervalStepType(this.wire);

  final String wire;

  static IntervalStepType fromWire(String wire) => values.firstWhere(
        (t) => t.wire == wire,
        orElse: () => throw ArgumentError.value(wire, 'wire', 'Unknown IntervalStepType code'),
      );
}

/// The target effort of an interval section — three steps
/// (könnyű · közepes · kemény), see docs/cardio/61 §3 M37 and §7.
///
/// Deliberately not a resistance level or a watt target: resistance runs on a
/// different scale on every machine, so a plan carrying it wouldn't be
/// reusable, and most home machines report no power at all.
enum IntervalIntensity {
  easy('EASY'),
  moderate('MODERATE'),
  hard('HARD');

  const IntervalIntensity(this.wire);

  final String wire;

  static IntervalIntensity fromWire(String wire) => values.firstWhere(
        (i) => i.wire == wire,
        orElse: () => throw ArgumentError.value(wire, 'wire', 'Unknown IntervalIntensity code'),
      );
}

/// One item of a [CardioIntervalPlan]. A [IntervalStepType.step] carries
/// [intensity] and [durationSeconds]; a [IntervalStepType.repeat] carries
/// [repeatCount] and [children], and never nests another block.
class IntervalStep {
  const IntervalStep.section({
    required this.intensity,
    required this.durationSeconds,
    this.name,
  })  : type = IntervalStepType.step,
        repeatCount = null,
        children = const [];

  const IntervalStep.block({
    required this.repeatCount,
    required this.children,
    this.name,
  })  : type = IntervalStepType.repeat,
        intensity = null,
        durationSeconds = null;

  final IntervalStepType type;
  final String? name;
  final IntervalIntensity? intensity;
  final int? durationSeconds;
  final int? repeatCount;
  final List<IntervalStep> children;

  /// How long this item takes once, in seconds: a section's own duration, or
  /// a block's children summed and multiplied by its repeat count.
  int get totalSeconds => switch (type) {
        IntervalStepType.step => durationSeconds ?? 0,
        IntervalStepType.repeat =>
          (repeatCount ?? 0) * children.fold(0, (sum, child) => sum + child.totalSeconds),
      };

  /// Seconds spent at [IntervalIntensity.hard] — the number that actually
  /// defines an interval plan (docs/cardio/61 §3 M37).
  int get hardSeconds => switch (type) {
        IntervalStepType.step =>
          intensity == IntervalIntensity.hard ? (durationSeconds ?? 0) : 0,
        IntervalStepType.repeat =>
          (repeatCount ?? 0) * children.fold(0, (sum, child) => sum + child.hardSeconds),
      };

  /// How many sections this item plays back as — a block counts its children
  /// once per repetition, because that's what the player counts down.
  int get sectionCount => switch (type) {
        IntervalStepType.step => 1,
        IntervalStepType.repeat =>
          (repeatCount ?? 0) * children.fold(0, (sum, child) => sum + child.sectionCount),
      };
}

/// A reusable interval plan (`/api/v1/cardio-interval-plans`): a named,
/// ordered list of sections and repeat blocks that the live MACHINE screen
/// plays back (docs/cardio/60 §6).
class CardioIntervalPlan {
  const CardioIntervalPlan({
    required this.clientId,
    required this.name,
    required this.steps,
    this.id,
  });

  final String clientId;
  final int? id;
  final String name;
  final List<IntervalStep> steps;

  /// The editor's three live numbers (docs/cardio/61 §3 M37), derived rather
  /// than stored — the backend doesn't store them either.
  int get totalSeconds => steps.fold(0, (sum, step) => sum + step.totalSeconds);

  int get hardSeconds => steps.fold(0, (sum, step) => sum + step.hardSeconds);

  int get sectionCount => steps.fold(0, (sum, step) => sum + step.sectionCount);
}
