/**
 * Formats cardio metrics (distance, pace, duration) for display — the web
 * session-row/detail-view counterpart of the mobile `CardioFormatter`
 * (`core/format/cardio_formatter.dart`). Metric-only: the web app has no
 * unit-system toggle yet (that lives in mobile Settings), so unlike the
 * mobile formatter this doesn't branch on `UnitSystem`.
 */

const METERS_PER_KM = 1000;

/** "8,42 km" (locale-aware decimal separator, always 2 decimals). */
export function formatDistanceKm(meters: number, locale: string): string {
  const km = meters / METERS_PER_KM;
  return `${new Intl.NumberFormat(locale, { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(km)} km`;
}

/** "5:12" under an hour, "1:05:12" from an hour up. */
export function formatDuration(totalSeconds: number): string {
  const seconds = Math.round(totalSeconds);
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  const ss = String(secs).padStart(2, "0");
  if (hours > 0) {
    return `${hours}:${String(minutes).padStart(2, "0")}:${ss}`;
  }
  return `${minutes}:${ss}`;
}

/**
 * "5:23 /km". Null when there's no distance to derive a pace from (avoids a
 * divide-by-zero rather than surfacing "0:00").
 */
export function formatPace(meters: number, durationSeconds: number): string | null {
  if (meters <= 0) return null;
  const secondsPerKm = durationSeconds / (meters / METERS_PER_KM);
  if (!Number.isFinite(secondsPerKm)) return null;
  const minutes = Math.floor(secondsPerKm / 60);
  const seconds = Math.round(secondsPerKm % 60);
  return `${minutes}:${String(seconds).padStart(2, "0")} /km`;
}
