import 'track_filter.dart';

/// The fastest *continuous* 1/5/10 km inside a session's filtered GPS trail
/// (docs/cardio/60-cardio-sport-specifics-plan.md C6.2) — the number a runner
/// means by "my best 5 km today", not the average pace extrapolated over 5 km
/// (docs/cardio/56-cardio-statistics-plan.md D-C3.8).
///
/// Works on the same **filtered** trail [computeSplits] does, and for the same
/// reason (see `cardio_splits_calculator.dart`): the simplified polyline
/// throws away exactly the distance/time resolution a window boundary needs.
///
/// Null means "this distance doesn't exist in this session" — a treadmill run
/// with no trail at all, or a session whose longest gap-free stretch is
/// shorter than the window. Never 0: a zero would read as an impossibly fast
/// record and would sit in the PR list forever (docs/cardio/60 §9).
class CardioBestEfforts {
  const CardioBestEfforts({
    this.best1kSeconds,
    this.best5kSeconds,
    this.best10kSeconds,
  });

  /// A session that produced no best effort at all — the treadmill/short-run
  /// case, and what a trail-less session stores.
  static const CardioBestEfforts none = CardioBestEfforts();

  final int? best1kSeconds;
  final int? best5kSeconds;
  final int? best10kSeconds;

  bool get isEmpty =>
      best1kSeconds == null && best5kSeconds == null && best10kSeconds == null;

  @override
  String toString() =>
      'CardioBestEfforts(1k: $best1kSeconds, 5k: $best5kSeconds, 10k: $best10kSeconds)';
}

/// The windows the app records, shortest first — the same trio the V69
/// columns and [CardioBestEfforts] carry.
const List<double> kBestEffortWindowsMeters = [1000, 5000, 10000];

/// Slides each of [kBestEffortWindowsMeters] along [trail] and keeps the
/// quickest crossing of it.
///
/// **Gaps invalidate a window rather than being bridged.** A stretch with no
/// fix for longer than [gapThreshold] (docs/cardio/54 §4.3's 60 s: a tunnel,
/// lost signal, an OS suspend, or a pause long enough to stop the recording)
/// is *not* connected with a straight line — the trail is cut there and each
/// gap-free piece is searched on its own. Without this, the two points
/// bracketing a gap look like one enormously fast segment and would hand the
/// runner a fictional record they can never beat (docs/cardio/60 §9). A
/// window may therefore never span a gap, only sit entirely inside one piece.
///
/// Window ends are **interpolated** inside the segment they fall in, exactly
/// as `computeSplits` interpolates its km boundaries, so a sparse trail
/// (points hundreds of meters apart) doesn't quantize the result to whichever
/// point happened to land near the boundary.
CardioBestEfforts computeBestEfforts(
  List<TrackFilterTrailPoint> trail, {
  Duration gapThreshold = const Duration(seconds: 60),
}) {
  final pieces = _splitOnGaps(trail, gapThreshold)
      .map(_DistanceTimeCurve.fromTrail)
      .whereType<_DistanceTimeCurve>()
      .toList();
  if (pieces.isEmpty) return CardioBestEfforts.none;

  return CardioBestEfforts(
    best1kSeconds: _bestEffortSeconds(pieces, kBestEffortWindowsMeters[0]),
    best5kSeconds: _bestEffortSeconds(pieces, kBestEffortWindowsMeters[1]),
    best10kSeconds: _bestEffortSeconds(pieces, kBestEffortWindowsMeters[2]),
  );
}

/// Slack for the "is this piece long enough to hold the window" test: a
/// cumulative sum of haversine segments lands a fraction of a millimeter
/// either side of a round number, and a run that covers exactly 5 km must not
/// have its best 5 km decided by which side it happened to land on.
const double _windowFitToleranceMeters = 0.001;

/// The quickest [windowMeters]-long crossing across every gap-free piece, or
/// null when no piece is that long.
///
/// Elapsed time as a function of covered distance is piecewise linear (each
/// trail segment is assumed to be covered at a constant speed — the only
/// assumption available between two fixes), so the window duration as the
/// window slides is piecewise linear too, and its minimum has to sit on a
/// breakpoint: a position where either the window's start or its end lands on
/// a trail point. Both families are enumerated below; checking only one of
/// them would miss minima that begin mid-segment.
int? _bestEffortSeconds(List<_DistanceTimeCurve> pieces, double windowMeters) {
  double? bestMs;

  void offer(double? candidateMs) {
    if (candidateMs == null) return;
    if (bestMs == null || candidateMs < bestMs!) bestMs = candidateMs;
  }

  for (final piece in pieces) {
    if (piece.totalMeters + _windowFitToleranceMeters < windowMeters) continue;
    for (var i = 0; i < piece.length; i++) {
      // Window starting on point i, ending interpolated.
      final end = piece.cumulativeMeters[i] + windowMeters;
      if (end <= piece.totalMeters + _windowFitToleranceMeters) {
        offer(piece.elapsedMsAt(end) - piece.elapsedMs[i]);
      }
      // Window ending on point i, starting interpolated.
      final start = piece.cumulativeMeters[i] - windowMeters;
      if (start >= 0) {
        offer(piece.elapsedMs[i] - piece.elapsedMsAt(start));
      }
    }
  }

  final result = bestMs;
  if (result == null) return null;
  // Rounding is monotonic, so the 1k <= 5k <= 10k invariant the V69 CHECK
  // enforces survives it.
  return (result / 1000).round();
}

/// Cuts [trail] wherever more than [gapThreshold] passed between two
/// consecutive points — same rule and same threshold `route_encoder.dart`
/// uses to draw a gap as a dashed line, applied here to decide which windows
/// are allowed to exist at all.
List<List<TrackFilterTrailPoint>> _splitOnGaps(
  List<TrackFilterTrailPoint> trail,
  Duration gapThreshold,
) {
  if (trail.length < 2) return const [];
  final pieces = <List<TrackFilterTrailPoint>>[];
  var current = <TrackFilterTrailPoint>[trail.first];
  for (var i = 1; i < trail.length; i++) {
    if (trail[i].recordedAt.difference(trail[i - 1].recordedAt) > gapThreshold) {
      pieces.add(current);
      current = <TrackFilterTrailPoint>[];
    }
    current.add(trail[i]);
  }
  pieces.add(current);
  return pieces;
}

/// One gap-free piece of a trail, as parallel cumulative distance/elapsed
/// arrays plus the linear interpolation between them.
class _DistanceTimeCurve {
  _DistanceTimeCurve._(this.cumulativeMeters, this.elapsedMs);

  final List<double> cumulativeMeters;
  final List<double> elapsedMs;

  int get length => cumulativeMeters.length;
  double get totalMeters => cumulativeMeters.last;

  /// Null for a piece that can't hold a window: fewer than two points, or no
  /// movement at all (a phone lying still still emits fixes).
  static _DistanceTimeCurve? fromTrail(List<TrackFilterTrailPoint> piece) {
    if (piece.length < 2) return null;
    final start = piece.first.recordedAt;
    final distances = <double>[0];
    final times = <double>[0];
    var cumulative = 0.0;
    for (var i = 1; i < piece.length; i++) {
      final prev = piece[i - 1];
      final curr = piece[i];
      final segment = haversineMeters(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );
      // A zero-length segment would make the interpolation ratio undefined,
      // and carries no information about speed either way.
      if (segment <= 0) continue;
      cumulative += segment;
      distances.add(cumulative);
      times.add(curr.recordedAt.difference(start).inMilliseconds.toDouble());
    }
    if (distances.length < 2 || cumulative <= 0) return null;
    return _DistanceTimeCurve._(distances, times);
  }

  /// Elapsed ms at [meters] along the piece, linearly interpolated inside the
  /// segment it falls in.
  double elapsedMsAt(double meters) {
    if (meters <= 0) return elapsedMs.first;
    if (meters >= totalMeters) return elapsedMs.last;

    var low = 0;
    var high = cumulativeMeters.length - 1;
    while (high - low > 1) {
      final mid = (low + high) ~/ 2;
      if (cumulativeMeters[mid] <= meters) {
        low = mid;
      } else {
        high = mid;
      }
    }

    final span = cumulativeMeters[high] - cumulativeMeters[low];
    if (span <= 0) return elapsedMs[low];
    final ratio = (meters - cumulativeMeters[low]) / span;
    return elapsedMs[low] + (elapsedMs[high] - elapsedMs[low]) * ratio;
  }
}
