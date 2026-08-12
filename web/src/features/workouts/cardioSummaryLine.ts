import { activityFamilyOf } from "./activityType";
import { formatDistanceKm, formatDuration, formatPace } from "./cardioFormat";
import type { WorkoutSessionResponse } from "./types";

/** Minimal shape of next-intl's translator — enough to call it with an interpolation value. */
type Translate = (key: string, values?: Record<string, string | number | Date>) => string;

/**
 * Family-dependent primary-metric summary line for a cardio session (W02):
 * DISTANCE → distance · duration · pace, MACHINE → duration · distance ·
 * avg watts, GAME → moving time · total time · avg heart rate. Parts a
 * family has no data for are simply omitted, never shown as a misleading
 * zero (docs/cardio M11).
 *
 * Shared across every place that lists a cardio session next to metric
 * numbers: the web session-row (`SessionsView`), and the trainer's
 * client-workouts / client-overview cards, which had the identical
 * "0 exercises · 0 kg volume" bug this line replaces for cardio
 * (docs/cardio/58-cardio-web-plan.md W2).
 */
export function buildCardioSummaryLine(session: WorkoutSessionResponse, t: Translate, locale: string): string {
  if (!session.activityType) return "";
  const family = activityFamilyOf(session.activityType);
  const cardio = session.cardio;
  const grossSeconds = session.finishedAt
    ? (new Date(session.finishedAt).getTime() - new Date(session.startedAt).getTime()) / 1000
    : null;
  const effectiveSeconds = session.movingSeconds ?? grossSeconds;
  const distanceM = cardio?.distanceMeters ?? null;

  const parts: string[] = [];
  if (family === "GAME") {
    if (session.movingSeconds != null) parts.push(`${formatDuration(session.movingSeconds)} ${t("movingTime")}`);
    if (grossSeconds != null && grossSeconds !== session.movingSeconds) {
      parts.push(`${formatDuration(grossSeconds)} ${t("totalTime")}`);
    }
    if (session.averageHeartRate != null) parts.push(t("bpmAvg", { value: Math.round(session.averageHeartRate) }));
    return parts.join(" · ");
  }

  // DISTANCE and MACHINE: no distance source falls back to duration only
  // (never a misleading "0.00 km"), mirroring the mobile M11 rule.
  if (distanceM != null && distanceM > 0) {
    if (family === "MACHINE") {
      if (effectiveSeconds != null) parts.push(formatDuration(effectiveSeconds));
      parts.push(formatDistanceKm(distanceM, locale));
      if (cardio?.avgWatts != null) parts.push(`${Math.round(cardio.avgWatts)} W`);
    } else {
      parts.push(formatDistanceKm(distanceM, locale));
      if (effectiveSeconds != null) parts.push(formatDuration(effectiveSeconds));
      const pace = effectiveSeconds != null ? formatPace(distanceM, effectiveSeconds) : null;
      if (pace) parts.push(pace);
    }
  } else if (effectiveSeconds != null) {
    parts.push(formatDuration(effectiveSeconds));
  }
  return parts.join(" · ");
}
