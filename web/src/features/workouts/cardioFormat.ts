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

/** "+42 m" / "−12 m" / "0 m" — a split's elevation change, always signed. */
export function formatElevationDelta(meters: number): string {
  const rounded = Math.round(meters);
  if (rounded > 0) return `+${rounded} m`;
  return `${rounded} m`;
}

/**
 * Total mechanical work in kilojoules — average power over the time it was
 * held (docs/cardio/60 §8 C7w.2, M39's "összmunka"). **Derived, never
 * stored**, exactly like the mobile `CardioFormatter.totalWorkKj`: it is
 * `avgWatts × movingSeconds / 1000`, so a stored copy could only ever
 * disagree with the two numbers it comes from. Null when there is no power
 * to derive it from — most home machines don't report watts, and a session
 * without them shows moving time in this card's place rather than a
 * misleading 0 kJ.
 */
export function totalWorkKj(avgWatts: number | null, movingSeconds: number | null): number | null {
  if (avgWatts == null || movingSeconds == null) return null;
  if (avgWatts <= 0 || movingSeconds <= 0) return null;
  return Math.round((avgWatts * movingSeconds) / 1000);
}

/** "1234 m" — a peak altitude or elevation gain (docs/cardio/60 §8 C8w.4), metric-only, whole meters. */
export function formatElevation(meters: number): string {
  return `${Math.round(meters)} m`;
}

/** "8.5 kg" — a hike's backpack weight (docs/cardio/60 §8 C8w.4), one decimal since a whole kg is coarse. */
export function formatWeight(kg: number): string {
  return `${kg.toFixed(1)} kg`;
}

/** "7 °C" — whole degrees, signed (winter hikes go below zero). */
export function formatTemperature(celsius: number): string {
  return `${Math.round(celsius)} °C`;
}

/** "12 km/h". */
export function formatWindSpeed(kph: number): string {
  return `${Math.round(kph)} km/h`;
}

/** "0 mm". */
export function formatPrecipitation(mm: number): string {
  return `${Math.round(mm)} mm`;
}
