import 'dart:math' as math;

import 'workout_session.dart';

/// How hard the session was, said in words — because the stacked bar's colours
/// alone are **not accessible to a colour-blind reader** (docs/cardio/61 §5
/// M43 is explicit about this). Derived from Z4+Z5 dominance.
enum HrZoneIntensity { easy, balanced, hard }

/// One zone's share of a session.
class HrZoneSlice {
  const HrZoneSlice({
    required this.zone,
    required this.seconds,
    required this.fraction,
  });

  /// 1-5 (`Z1`…`Z5`).
  final int zone;
  final int seconds;

  /// Share of the panel's total, 0..1 — already normalized, so a stacked bar
  /// built from these can never overflow its track.
  final double fraction;
}

/// The heart-rate zone distribution of a finished cardio session, from the
/// `hrZone1..5Seconds` columns that have been carried end to end since C5 but
/// never displayed anywhere (docs/cardio/60 §1 point 1). Built for the M43
/// panel, which is **one component for every cardio type** (Q-D7) — only its
/// position on the summary is family-dependent.
///
/// Two things this type exists to get right, both of them silent failures:
///
/// 1. **The zone seconds must never total more than the gross session time.**
///    The watch and the phone can both write zone data (docs/cardio/55 R8),
///    and a mixed pair of measurements sums to more time than the session
///    lasted — which would draw a bar wider than its track and a "112% in
///    zone" reading. [totalSeconds] is therefore capped, and [exceedsGross]
///    reports the inconsistency instead of hiding it.
/// 2. **Partial data is not the same as complete data.** A watch paired
///    half-way through leaves zones covering only part of the session; the
///    panel hatches the remainder rather than stretching the zones over it
///    (M43's `részleges pulzusadat` state), which is what [coverageFraction]
///    is for.
class HrZoneBreakdown {
  const HrZoneBreakdown._({
    required this.slices,
    required this.totalSeconds,
    required this.grossSeconds,
    required this.exceedsGross,
  });

  /// Always five entries, `Z1`…`Z5`, including zero-second ones — the panel
  /// lists all five rows so a reader can see which zones were *not* touched.
  final List<HrZoneSlice> slices;

  /// Seconds accounted for by zones, capped at [grossSeconds] (see the class
  /// doc's point 1).
  final int totalSeconds;

  /// The session's gross duration, the denominator for [coverageFraction].
  final int grossSeconds;

  /// True when the raw zone seconds summed to more than the session lasted —
  /// a data bug, not a workout. Kept as a flag rather than silently rescaled
  /// so a test can catch it and the UI never has to guess.
  final bool exceedsGross;

  /// Null when the session carries no zone data at all — the most common case
  /// by far, and the panel disappears entirely for it (M43) rather than
  /// showing five zeroes.
  static HrZoneBreakdown? fromSession(WorkoutSession session) {
    final cardio = session.cardio;
    if (cardio == null) return null;
    final raw = <int>[
      cardio.hrZone1Seconds ?? 0,
      cardio.hrZone2Seconds ?? 0,
      cardio.hrZone3Seconds ?? 0,
      cardio.hrZone4Seconds ?? 0,
      cardio.hrZone5Seconds ?? 0,
    ];
    final rawTotal = raw.fold(0, (a, b) => a + b);
    if (rawTotal <= 0) return null;

    // Gross time, not moving time: a zone second is measured by the heart,
    // which keeps beating while the session is paused (docs/cardio/61 §5's
    // GAME header shows playing time and gross time side by side).
    final gross = session.effectiveDuration?.inSeconds ?? 0;
    final exceedsGross = gross > 0 && rawTotal > gross;
    final total = gross > 0 ? math.min(rawTotal, gross) : rawTotal;

    // Fractions are taken against the raw total, so the five slices always
    // fill exactly the accounted-for part of the bar — the unaccounted
    // remainder is [coverageFraction]'s business, not a sixth slice.
    return HrZoneBreakdown._(
      slices: [
        for (var i = 0; i < 5; i++)
          HrZoneSlice(zone: i + 1, seconds: raw[i], fraction: raw[i] / rawTotal),
      ],
      totalSeconds: total,
      grossSeconds: gross,
      exceedsGross: exceedsGross,
    );
  }

  /// How much of the session the zones actually cover, 0..1. Exactly 1 when
  /// the whole session was measured (and whenever the gross time is unknown,
  /// since there is then nothing to be short of).
  double get coverageFraction {
    if (grossSeconds <= 0) return 1;
    return (totalSeconds / grossSeconds).clamp(0.0, 1.0);
  }

  /// True when a meaningful slice of the session has no zone data — the
  /// hatched-remainder state. The 2% tolerance keeps a rounding second from
  /// declaring a fully-measured session partial.
  bool get isPartial => coverageFraction < 0.98;

  int secondsIn(int zone) => slices[zone - 1].seconds;

  /// Z4+Z5's share of the measured time. The one number M43's headline chip
  /// is derived from.
  double get hardFraction => slices[3].fraction + slices[4].fraction;

  /// The thresholds are deliberately plain: a third of the measured time at
  /// threshold or above is a hard session, under a tenth is an easy one, and
  /// the band between is balanced. No profile input and no estimation — M43's
  /// closing line promises exactly that ("Becslés nincs").
  HrZoneIntensity get intensity {
    if (hardFraction >= 0.33) return HrZoneIntensity.hard;
    if (hardFraction < 0.10) return HrZoneIntensity.easy;
    return HrZoneIntensity.balanced;
  }
}
