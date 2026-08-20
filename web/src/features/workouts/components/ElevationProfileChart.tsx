import { useTranslations } from "next-intl";
import { formatElevation } from "../cardioFormat";

const WIDTH = 400;
const HEIGHT = 120;

interface ElevationProfileChartProps {
  altitudes: number[];
  elevationGainMeters: number;
}

/**
 * The web's **only** elevation profile — the mobile "C4a.6-era approximation"
 * fallback (`cardio_summary_screen.dart`'s "EGYSZERŰSÍTETT" state,
 * docs/cardio/60 §8 C8w.1), never the real C8.3 profile. The real one is
 * built from a session's *local* raw GPS track points, which only ever live
 * on the recording phone (docs/cardio/52 D-C1.2) — the web has no way to
 * read them, ever, for any session. So unlike every other "shows a badge
 * only in the degraded case" component on this page, the **SIMPLIFIED badge
 * here is unconditional**: that's not a bug, it's a structural fact about
 * what data the web can see.
 *
 * The X axis is a synthetic per-point index, not real distance — the
 * decoded polyline carries no timestamps, and (mirroring mobile's own
 * fallback) this chart's job is only to show the route's *shape* (where it
 * climbed/descended), not precise pacing. Segment boundaries (GPS gaps)
 * don't interrupt the index or get shaded, matching mobile's fallback
 * exactly — that treatment is reserved for the real C8.3 profile.
 */
export function ElevationProfileChart({ altitudes, elevationGainMeters }: ElevationProfileChartProps) {
  const t = useTranslations("workouts");
  if (altitudes.length < 2) return null;

  const min = Math.min(...altitudes);
  const max = Math.max(...altitudes);
  const span = max - min;
  const points = altitudes.map((alt, i) => {
    const x = (i / (altitudes.length - 1)) * WIDTH;
    const y = span === 0 ? HEIGHT / 2 : HEIGHT - ((alt - min) / span) * HEIGHT;
    return `${x},${y}`;
  });

  return (
    <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
      <div className="flex items-center justify-between mb-3">
        <p className="text-sm font-semibold" style={{ color: "var(--on-surface-variant)" }}>
          {t("cardioElevationProfileHeading")}
        </p>
        <div className="flex items-center gap-1.5">
          <span
            className="px-1.5 py-0.5 rounded-[var(--r-pill)] text-[9px] font-extrabold uppercase"
            style={{ background: "var(--surface-highest)", color: "var(--on-surface-variant)" }}
          >
            {t("cardioElevationProfileSimplifiedBadge")}
          </span>
          <span className="text-xs font-bold tabular" style={{ color: "var(--on-surface-variant)" }}>
            +{formatElevation(elevationGainMeters)}
          </span>
        </div>
      </div>
      <svg viewBox={`0 0 ${WIDTH} ${HEIGHT}`} className="w-full h-auto" role="img" aria-hidden="true">
        <polyline points={points.join(" ")} fill="none" stroke="var(--primary)" strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
      </svg>
    </div>
  );
}
