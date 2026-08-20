import { useTranslations, useLocale } from "next-intl";
import { format } from "date-fns";
import { StatCard } from "@/components/data/StatCard";
import { ActivityChip } from "./ActivityChip";
import { RouteSvg } from "./RouteSvg";
import { CardioSplitsTable } from "./CardioSplitsTable";
import { PaceBarChart } from "./PaceBarChart";
import { BestEffortsCard } from "./BestEffortsCard";
import { HrZonePanel } from "./HrZonePanel";
import { TotalWorkCard } from "./TotalWorkCard";
import { CalorieCard } from "./CalorieCard";
import { ElevationProfileChart } from "./ElevationProfileChart";
import { WaypointsList } from "./WaypointsList";
import { WeatherCard } from "./WeatherCard";
import { activityFamilyOf, activityTypeColor } from "../activityType";
import { buildCardioTiles } from "../cardioTiles";
import { detectBestEffortRecords } from "../cardioBestEffortRecords";
import { buildHrZoneBreakdown } from "../hrZoneBreakdown";
import { totalWorkKj } from "../cardioFormat";
import { flattenAltitudes } from "../routeGeometry";
import type { WorkoutSessionResponse } from "../types";

/**
 * Read-only cardio session view — the `kind`-branch counterpart of
 * `SessionLogger` for a `CARDIO` session (docs/cardio/58-cardio-web-plan.md
 * D-W.2: the web never edits cardio, only displays/filters/statisticizes;
 * D-W.1: it can't be started from the web either, so there's no "active"
 * state to render here, only a finished — or mid-flight-on-another-device —
 * session).
 *
 * Route (`RouteSvg`) and splits (`CardioSplitsTable`, plus the optional
 * `PaceBarChart` above its rows) render for the `DISTANCE` family when the
 * session carried them (docs/cardio/60 §8 W0w — this used to be "route-free
 * and split-free" by design before C4a shipped GPS tracking; that's no
 * longer true, the components below are the catch-up). Neither renders
 * anything for a session with no route/splits, so a footpod-only run or a
 * treadmill session looks exactly as before.
 *
 * `BestEffortsCard` (docs/cardio/60 §8 C6w.2) sits between the metric grid
 * and the route, same position as the mobile `_bestEffortSection` — and,
 * like mobile, gated on `DISTANCE`, not `RUNNING`: `computeBestEfforts` runs
 * for the whole family, so a fast walk or hike can have a best 1/5/10 km too.
 * Its record badge (docs/cardio/60 §8 C6w.4) comes from `history`: cardio PRs
 * have no server-side storage, so `detectBestEffortRecords` recomputes
 * "did this session beat every earlier RUNNING session" from the session
 * list the caller already fetched — no backend change needed. `history`
 * defaults to empty, which yields no records rather than crashing a caller
 * that doesn't have the full list handy.
 *
 * `HrZonePanel` (docs/cardio/60 §8 C9w.1) is **one component for every
 * cardio type** (Q-D7) — only its position differs by family, same as
 * mobile: `DISTANCE` and `MACHINE` get it after their family-specific cards
 * (mobile's "a »nincs útvonal« kártya után" — the web has no no-route
 * placeholder, so it lands after `CalorieCard` instead), `GAME` right after
 * the metric grid (mobile's "domináns szám után"). `null` when the session
 * carries no zone data at all.
 *
 * `TotalWorkCard`/`CalorieCard`/`CardioSplitsTable`'s interval mode
 * (docs/cardio/60 §8 C7w.1–C7w.2) are MACHINE-only: the kJ hero renders only
 * when `totalWorkKj` is derivable (needs both avgWatts and movingSeconds);
 * the two-sided calorie card **always** renders for MACHINE, matching
 * mobile's unconditional `_CalorieCard` — both sides show "—" rather than
 * the card disappearing, because the footnote explaining why the machine
 * number is never summed is worth showing even with no numbers yet.
 *
 * `ElevationProfileChart`/`WaypointsList`/`WeatherCard` (docs/cardio/60 §8
 * C8w.1–C8w.4) are HIKING-specific (the profile technically renders for any
 * `DISTANCE` session with a route + elevation gain, matching mobile, but in
 * practice only hikes climb enough to record one). The profile is **always**
 * the simplified fallback — the web can never see a session's local raw GPS
 * points (they only ever live on the recording phone), so it can never build
 * mobile's real C8.3 profile, not even for a session recorded today.
 *
 * The metric tiles (`buildCardioTiles`) mirror the mobile
 * `CardioSummaryScreen._metricSections` field selection exactly, not the
 * W03 desktop mockup's full metric-grid + zones + splits, so the same
 * session shows the same fields on both platforms.
 */
export function CardioSessionDetail({
  session,
  history = [],
}: {
  session: WorkoutSessionResponse;
  history?: WorkoutSessionResponse[];
}) {
  const t = useTranslations("workouts");
  const ta = useTranslations("workouts.activityTypes");
  const locale = useLocale();

  const activityType = session.activityType ?? "OTHER_CARDIO";
  const family = activityFamilyOf(activityType);
  const color = activityTypeColor(activityType);
  const tiles = buildCardioTiles(session, t, locale);
  const polyline = session.cardio?.routePolyline;
  const bestEffortRecords = detectBestEffortRecords(history, session);
  const hrZoneBreakdown = buildHrZoneBreakdown(session);
  const workKj = totalWorkKj(session.cardio?.avgWatts ?? null, session.movingSeconds);
  const altitudes = polyline ? flattenAltitudes(polyline) : [];
  const hasWeatherData =
    session.cardio?.weatherTempC != null ||
    session.cardio?.weatherWindKph != null ||
    session.cardio?.weatherPrecipMm != null ||
    session.cardio?.weatherCondition != null;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-3 rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
        <ActivityChip activityType={activityType} size={40} />
        <div className="flex-1 min-w-0">
          <p className="font-bold text-base truncate">{ta(activityType)}</p>
          <p className="text-xs tabular" style={{ color: "var(--muted)" }}>
            {format(new Date(session.startedAt), "MMM d, yyyy · HH:mm")}
          </p>
        </div>
        {session.rpe != null && (
          <span className="px-2 py-0.5 rounded-[var(--r-pill)] text-xs font-bold flex-none"
            style={{ background: "color-mix(in srgb, var(--secondary) 18%, transparent)", color: "var(--secondary)" }}>
            {t("sessionRpe", { rpe: session.rpe })}
          </span>
        )}
        <div className="flex items-center gap-1 rounded-[var(--r-pill)] px-3 py-1.5 flex-none" style={{ background: "var(--surface-container)" }}>
          <span className="material-symbols-rounded text-sm" style={{ color: "var(--muted)" }}>lock</span>
          <span className="text-xs font-bold" style={{ color: "var(--muted)" }}>{t("readOnly")}</span>
        </div>
      </div>

      {session.feedbackNote && (
        <p className="text-sm rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)", color: "var(--on-surface-variant)" }}>
          {session.feedbackNote}
        </p>
      )}

      <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
        {tiles.map((tile) => (
          <StatCard key={tile.label} label={tile.label} value={tile.value} icon={tile.icon} color={color} />
        ))}
      </div>

      {family === "GAME" && hrZoneBreakdown && <HrZonePanel breakdown={hrZoneBreakdown} />}

      {family === "MACHINE" && workKj != null && session.cardio?.avgWatts != null && (
        <TotalWorkCard
          totalWorkKj={workKj}
          avgWatts={session.cardio.avgWatts}
          maxWatts={session.cardio.maxWatts}
          accent={color}
        />
      )}

      {family === "MACHINE" && (
        <CardioSplitsTable splits={session.splits} accent={color} />
      )}

      {family === "MACHINE" && (
        <CalorieCard
          activeCalories={session.activeCalories}
          machineCalories={session.cardio?.deviceCalories ?? null}
          machineEdited={session.cardio?.caloriesSource === "MANUAL"}
          accent={color}
        />
      )}

      {family === "MACHINE" && hrZoneBreakdown && <HrZonePanel breakdown={hrZoneBreakdown} />}

      {family === "DISTANCE" && session.cardio && (
        <BestEffortsCard cardio={session.cardio} records={bestEffortRecords} />
      )}

      {family === "DISTANCE" && activityType === "HIKING" && hasWeatherData && (
        <WeatherCard
          condition={session.cardio?.weatherCondition ?? null}
          tempC={session.cardio?.weatherTempC ?? null}
          windKph={session.cardio?.weatherWindKph ?? null}
          precipMm={session.cardio?.weatherPrecipMm ?? null}
          startedAt={session.startedAt}
        />
      )}

      {family === "DISTANCE" && polyline && (
        <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
          <p className="text-sm font-semibold mb-3" style={{ color: "var(--on-surface-variant)" }}>
            {t("cardioRouteHeading")}
          </p>
          <RouteSvg polyline={polyline} waypoints={session.waypoints} />
        </div>
      )}

      {family === "DISTANCE" && session.cardio?.elevationGainMeters != null && (
        <ElevationProfileChart altitudes={altitudes} elevationGainMeters={session.cardio.elevationGainMeters} />
      )}

      {family === "DISTANCE" && activityType === "HIKING" && (
        <WaypointsList waypoints={session.waypoints} accent={color} />
      )}

      {family === "DISTANCE" && (
        <CardioSplitsTable
          splits={session.splits}
          chart={<PaceBarChart splits={session.splits} accent={color} />}
        />
      )}

      {family === "DISTANCE" && hrZoneBreakdown && <HrZonePanel breakdown={hrZoneBreakdown} />}
    </div>
  );
}
