import type { WorkoutSessionResponse } from "./types";

/**
 * How hard the session was, said in words — the web port of the mobile
 * `HrZoneBreakdown` (`domain/hr_zone_breakdown.dart`, docs/cardio/60 §8
 * C9w.1). Same two silent-failure guards as the Dart original:
 *
 * 1. **The zone seconds must never total more than the gross session time.**
 *    The watch and the phone can both write zone data, and a mixed pair of
 *    measurements can sum to more time than the session lasted — which would
 *    draw a bar wider than its track and a "112% in zone" reading.
 *    `totalSeconds` is capped at the gross duration, and `exceedsGross`
 *    reports the inconsistency instead of hiding it.
 * 2. **Partial data is not the same as complete data.** A watch paired
 *    half-way through leaves zones covering only part of the session;
 *    `coverageFraction`/`isPartial` are for the panel to hatch the
 *    unmeasured remainder rather than stretch the zones over it.
 */

export type HrZoneIntensity = "easy" | "balanced" | "hard";

/** One zone's share of a session. `fraction` is 0..1, against the *measured* total. */
export interface HrZoneSlice {
  /** 1-5 (Z1…Z5). */
  zone: number;
  seconds: number;
  fraction: number;
}

export interface HrZoneBreakdown {
  /** Always five entries, Z1…Z5, including zero-second ones. */
  slices: HrZoneSlice[];
  /** Seconds accounted for by zones, capped at `grossSeconds`. */
  totalSeconds: number;
  grossSeconds: number;
  /** True when the raw zone seconds summed to more than the session lasted — a data bug, not a workout. */
  exceedsGross: boolean;
  /** How much of the session the zones actually cover, 0..1. 1 when fully measured or gross time is unknown. */
  coverageFraction: number;
  /** True when a meaningful slice of the session has no zone data (2% tolerance against rounding). */
  isPartial: boolean;
  /** Z4+Z5's share of the *measured* time. */
  hardFraction: number;
  intensity: HrZoneIntensity;
}

/**
 * Builds the breakdown from a finished session, or `null` when it carries no
 * zone data at all — the most common case by far, and the panel disappears
 * entirely for it rather than showing five zeroes.
 */
export function buildHrZoneBreakdown(session: WorkoutSessionResponse): HrZoneBreakdown | null {
  const cardio = session.cardio;
  if (cardio == null) return null;

  const raw = [
    cardio.hrZone1Seconds ?? 0,
    cardio.hrZone2Seconds ?? 0,
    cardio.hrZone3Seconds ?? 0,
    cardio.hrZone4Seconds ?? 0,
    cardio.hrZone5Seconds ?? 0,
  ];
  const rawTotal = raw.reduce((a, b) => a + b, 0);
  if (rawTotal <= 0) return null;

  // Gross time, not moving time: a zone second is measured by the heart,
  // which keeps beating while the session is paused.
  const gross =
    session.finishedAt != null
      ? Math.round((new Date(session.finishedAt).getTime() - new Date(session.startedAt).getTime()) / 1000)
      : 0;
  const exceedsGross = gross > 0 && rawTotal > gross;
  const totalSeconds = gross > 0 ? Math.min(rawTotal, gross) : rawTotal;

  // Fractions are taken against the raw total, so the five slices always
  // fill exactly the accounted-for part of the bar — the unaccounted
  // remainder is coverageFraction's business, not a sixth slice.
  const slices: HrZoneSlice[] = raw.map((seconds, i) => ({ zone: i + 1, seconds, fraction: seconds / rawTotal }));

  const coverageFraction = gross <= 0 ? 1 : Math.min(1, Math.max(0, totalSeconds / gross));
  const isPartial = coverageFraction < 0.98;
  const hardFraction = slices[3].fraction + slices[4].fraction;
  const intensity: HrZoneIntensity = hardFraction >= 0.33 ? "hard" : hardFraction < 0.1 ? "easy" : "balanced";

  return { slices, totalSeconds, grossSeconds: gross, exceedsGross, coverageFraction, isPartial, hardFraction, intensity };
}
