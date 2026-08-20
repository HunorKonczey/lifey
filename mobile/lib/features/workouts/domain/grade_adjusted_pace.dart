import 'track_filter.dart';

/// Grade-adjusted pace: what a session's average pace would be on flat
/// ground, given the effort actually spent (docs/cardio/60 C8.2,
/// docs/cardio/56-cardio-statistics-plan.md D-C3.9 — the full derivation and
/// worked formula live there; this file is the **one place the formula is
/// implemented**, referenced from there rather than duplicated).
///
/// Not a linear "penalty per % grade" — a 15% downhill doesn't cost half of
/// a 15% uphill; past a certain steepness a downhill gets *more* expensive
/// again (braking, eccentric muscle work). The model here is Minetti et al.
/// (2002, *J Appl Physiol* 93.3: 1039–1046)'s quintic fit to measured
/// running energy cost, the same curve most published GAP tools use.

/// Minetti's polynomial: metabolic cost of running one horizontal meter at
/// grade [i] (a fraction, e.g. 0.10 for a 10% climb), in J·kg⁻¹·m⁻¹.
/// Clamped to ±45% — the range the paper's own measurements cover; a grade
/// outside it is GPS/altitude noise on a very short segment, not a real
/// slope, and the polynomial isn't validated out there anyway.
double _minettiCostPerMeter(double grade) {
  final i = grade.clamp(-0.45, 0.45);
  final i2 = i * i;
  final i3 = i2 * i;
  final i4 = i3 * i;
  final i5 = i4 * i;
  return 155.4 * i5 - 30.4 * i4 - 43.3 * i3 + 46.3 * i2 + 19.5 * i + 3.6;
}

/// Minetti's own flat-running reference cost, `C(0)` — a measured constant
/// from the paper, not a separately-chosen baseline.
const double _flatCostPerMeter = 3.6;

/// Grade-adjusted pace over [trail], in seconds per km — or null when there
/// isn't enough trail to compute one (docs/cardio/56 D-C3.9's own "hiányzó
/// adat, nem 0" rule: a GPS-less indoor session, or fewer than two points,
/// has no GAP concept, and a fabricated 0 would look like an impossibly
/// fast pace).
///
/// Walks the trail segment by segment: each segment's grade converts its
/// horizontal distance into a "flat-equivalent" distance via
/// `C(grade)/C(0)`, and the result is total elapsed time over total
/// flat-equivalent distance — the same "duration over distance" shape every
/// other pace figure in this app uses, just fed a corrected distance instead
/// of the raw one. On a perfectly flat trail every segment's ratio is
/// exactly 1, so the flat-equivalent distance equals the real one and this
/// collapses to the plain average pace (docs/cardio/60 C8.2's kész-ha).
///
/// A segment missing altitude at either end is treated as flat (ratio 1)
/// rather than dropped — one gap in the altitude stream shouldn't discard
/// the segment's distance and time entirely, same "don't punish a single
/// missing reading" choice `cardio_splits_calculator.dart`'s
/// `_interpolateAltitude` makes.
///
/// **The direction is easy to get backward, so spell it out**: uphill costs
/// more per meter than flat (`costRatio > 1`), which *inflates* the
/// flat-equivalent distance for the same elapsed time — so GAP comes out
/// *faster* (a smaller seconds/km) than the raw GPS pace, crediting the
/// climb. Downhill costs less (`costRatio < 1` down to about -20%, per
/// Minetti's measured minimum), which shrinks the flat-equivalent distance —
/// so GAP comes out *slower* than raw, discounting the free downhill speed.
/// Past roughly -20% the curve climbs back toward (and eventually above)
/// flat cost, so a very steep descent's GAP drifts back toward — and can
/// even beat — the raw pace again.
double? computeGradeAdjustedPaceSecondsPerKm(List<TrackFilterTrailPoint> trail) {
  if (trail.length < 2) return null;

  var totalSeconds = 0.0;
  var totalFlatEquivalentMeters = 0.0;

  for (var i = 1; i < trail.length; i++) {
    final prev = trail[i - 1];
    final curr = trail[i];
    final segmentDistance =
        haversineMeters(prev.latitude, prev.longitude, curr.latitude, curr.longitude);
    if (segmentDistance <= 0) continue;

    final elapsedSeconds = curr.recordedAt.difference(prev.recordedAt).inMilliseconds / 1000.0;
    if (elapsedSeconds <= 0) continue;

    final grade = (prev.altitude != null && curr.altitude != null)
        ? (curr.altitude! - prev.altitude!) / segmentDistance
        : 0.0;
    final costRatio = _minettiCostPerMeter(grade) / _flatCostPerMeter;

    totalFlatEquivalentMeters += segmentDistance * costRatio;
    totalSeconds += elapsedSeconds;
  }

  if (totalFlatEquivalentMeters <= 0) return null;
  return totalSeconds * 1000 / totalFlatEquivalentMeters;
}
