import { useTranslations } from "next-intl";
import { formatElevation } from "../cardioFormat";
import type { CardioWaypointResponse } from "../types";

interface WaypointsListProps {
  waypoints: CardioWaypointResponse[];
  accent: string;
}

/**
 * M42's ÚTPONTOK list, HIKING-only (docs/cardio/60 §8 C8w.3) — narrower than
 * mobile's `_WaypointRow`, which shows "distance · altitude · elapsed" per
 * row. Mobile derives distance/elapsed by matching each waypoint against the
 * session's **local** raw track points (`matchWaypointsToTrail`); the web
 * has no local track for any session, ever (docs/cardio/52 D-C1.2), and the
 * server-side `CardioWaypointResponse` stores neither field — only
 * `waypointIndex`/`latitude`/`longitude`/`altitudeMeters`/`label`. So unlike
 * mobile, distance and elapsed time aren't "usually missing", they're not a
 * concept the web can ever compute — showing two permanent "—"s per row
 * would be worse than just not promising them. Altitude is the one number
 * both platforms can show, since it's the waypoint's own stored value (the
 * same fallback mobile itself uses when trail-matching finds nothing).
 */
export function WaypointsList({ waypoints, accent }: WaypointsListProps) {
  const t = useTranslations("workouts");
  if (waypoints.length === 0) return null;

  const sorted = [...waypoints].sort((a, b) => a.waypointIndex - b.waypointIndex);

  return (
    <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
      <div className="flex items-center justify-between mb-3">
        <p className="text-sm font-semibold" style={{ color: "var(--on-surface-variant)" }}>
          {t("cardioWaypointsHeading")}
        </p>
        <span
          className="px-2 py-0.5 rounded-[var(--r-pill)] text-xs font-bold"
          style={{ background: `color-mix(in srgb, ${accent} 16%, transparent)`, color: accent }}
        >
          {t("cardioWaypointsCountChip", { count: sorted.length })}
        </span>
      </div>
      <div className="flex flex-col gap-2">
        {sorted.map((waypoint) => (
          <div key={waypoint.waypointIndex} className="flex items-center gap-3 text-sm">
            <span className="w-6 flex-none text-right font-extrabold tabular" style={{ color: "var(--on-surface-variant)" }}>
              {waypoint.waypointIndex + 1}
            </span>
            <span className="font-bold tabular" style={{ color: "var(--on-surface)" }}>
              {waypoint.altitudeMeters != null ? formatElevation(waypoint.altitudeMeters) : "—"}
            </span>
            {waypoint.label && (
              <span className="truncate" style={{ color: "var(--on-surface-variant)" }}>
                {waypoint.label}
              </span>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
