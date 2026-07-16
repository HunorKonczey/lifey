/// The three record types a logged set can break
/// (docs/38-personal-records-plan.md).
enum PrType { maxWeight, repsAtWeight, estimatedOneRm }

/// Epley formula: weight × (1 + reps / 30).
double estimateOneRepMax(double weight, int reps) => weight * (1 + reps / 30);

/// One previously logged set, as far as PR detection needs it.
typedef PrSet = ({double weight, int reps, DateTime performedAt});

/// The "best so far" values a candidate set is compared against — never
/// includes the candidate itself. Purely derived from history, never
/// persisted (see [PrBaseline.fromSets] and [detectPrs]).
class PrBaseline {
  const PrBaseline({
    this.maxWeight,
    this.bestOneRm,
    this.maxRepsByWeight = const {},
  });

  /// Highest weight ever lifted (bodyweight/0 kg sets excluded — see
  /// [PrBaseline.fromSets]). Null when no qualifying set exists yet.
  final double? maxWeight;

  /// Best estimated 1RM ever reached (0 kg sets excluded). Null when no
  /// qualifying set exists yet.
  final double? bestOneRm;

  /// Most reps ever done at each exact weight (0 kg included — a
  /// bodyweight rep record is meaningful). Keyed by exact weight value;
  /// weights come from parsed text input, never arithmetic, so exact
  /// equality is safe.
  final Map<double, int> maxRepsByWeight;

  static const empty = PrBaseline();

  /// Builds a baseline from a set of prior sets (order doesn't matter).
  factory PrBaseline.fromSets(Iterable<PrSet> sets) {
    double? maxWeight;
    double? bestOneRm;
    final maxRepsByWeight = <double, int>{};

    for (final s in sets) {
      if (s.weight > 0) {
        if (maxWeight == null || s.weight > maxWeight) maxWeight = s.weight;
        final orm = estimateOneRepMax(s.weight, s.reps);
        if (bestOneRm == null || orm > bestOneRm) bestOneRm = orm;
      }
      final currentReps = maxRepsByWeight[s.weight];
      if (currentReps == null || s.reps > currentReps) {
        maxRepsByWeight[s.weight] = s.reps;
      }
    }

    return PrBaseline(
      maxWeight: maxWeight,
      bestOneRm: bestOneRm,
      maxRepsByWeight: maxRepsByWeight,
    );
  }

  /// Returns a new baseline with [set] folded in — used to advance the
  /// running in-session baseline as each done row is logged, without
  /// re-scanning every earlier set on every keystroke.
  PrBaseline extend(PrSet set) {
    var nextMaxWeight = maxWeight;
    var nextBestOneRm = bestOneRm;
    if (set.weight > 0) {
      if (nextMaxWeight == null || set.weight > nextMaxWeight) {
        nextMaxWeight = set.weight;
      }
      final orm = estimateOneRepMax(set.weight, set.reps);
      if (nextBestOneRm == null || orm > nextBestOneRm) nextBestOneRm = orm;
    }
    final nextMaxReps = Map<double, int>.of(maxRepsByWeight);
    final currentReps = nextMaxReps[set.weight];
    if (currentReps == null || set.reps > currentReps) {
      nextMaxReps[set.weight] = set.reps;
    }
    return PrBaseline(
      maxWeight: nextMaxWeight,
      bestOneRm: nextBestOneRm,
      maxRepsByWeight: nextMaxReps,
    );
  }
}

/// Detects which record types a candidate (weight, reps) set breaks against
/// [baseline]. Strictly-greater semantics — matching the existing best is
/// not a new record. A record type never fires without a baseline value to
/// beat (a never-before-seen weight is not a "reps PR"; an all-bodyweight
/// history has no max-weight/e1RM baseline to beat).
List<PrType> detectPrs(
  PrBaseline baseline, {
  required double weight,
  required int reps,
}) {
  final types = <PrType>[];

  if (weight > 0) {
    if (baseline.maxWeight != null && weight > baseline.maxWeight!) {
      types.add(PrType.maxWeight);
    }
    if (baseline.bestOneRm != null) {
      final orm = estimateOneRepMax(weight, reps);
      if (orm > baseline.bestOneRm!) types.add(PrType.estimatedOneRm);
    }
  }

  final priorRepsAtWeight = baseline.maxRepsByWeight[weight];
  if (priorRepsAtWeight != null && reps > priorRepsAtWeight) {
    types.add(PrType.repsAtWeight);
  }

  return types;
}

/// A single moment a record type's running best increased.
class PrEvent {
  const PrEvent({
    required this.type,
    required this.weight,
    required this.reps,
    required this.performedAt,
  });

  final PrType type;
  final double weight;
  final int reps;
  final DateTime performedAt;
}

/// Walks [sets] forward in time, appending a [PrEvent] for every record type
/// whose running best increases. [sets] must already be sorted by
/// [PrSet.performedAt] ascending (oldest first) — the caller owns sorting,
/// since callers already hold sets in different orders for other purposes.
List<PrEvent> computePrHistory(List<PrSet> sets) {
  final events = <PrEvent>[];
  var baseline = PrBaseline.empty;

  for (final s in sets) {
    final types = detectPrs(baseline, weight: s.weight, reps: s.reps);
    for (final type in types) {
      events.add(PrEvent(
        type: type,
        weight: s.weight,
        reps: s.reps,
        performedAt: s.performedAt,
      ));
    }
    baseline = baseline.extend(s);
  }

  return events;
}

/// Same running-baseline walk as [computePrHistory], but returns one record
/// list per input position instead of a flattened event list — for callers
/// that need to map results back onto a specific row (e.g. a session
/// screen's live per-set PR badge), where [sets] starts from a real
/// [baseline] (the exercise's history before this session) rather than
/// [PrBaseline.empty]. [sets] must already be sorted oldest-first.
List<List<PrType>> detectPrsInOrder(PrBaseline baseline, List<PrSet> sets) {
  final result = <List<PrType>>[];
  var running = baseline;
  for (final s in sets) {
    result.add(detectPrs(running, weight: s.weight, reps: s.reps));
    running = running.extend(s);
  }
  return result;
}
