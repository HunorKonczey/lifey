import { useTranslations, useLocale } from "next-intl";
import { format } from "date-fns";
import { StatCard } from "@/components/data/StatCard";
import { ActivityChip } from "./ActivityChip";
import { activityTypeColor } from "../activityType";
import { buildCardioTiles } from "../cardioTiles";
import type { WorkoutSessionResponse } from "../types";

/**
 * Read-only cardio session view — the `kind`-branch counterpart of
 * `SessionLogger` for a `CARDIO` session (docs/cardio/58-cardio-web-plan.md
 * D-W.2: the web never edits cardio, only displays/filters/statisticizes;
 * D-W.1: it can't be started from the web either, so there's no "active"
 * state to render here, only a finished — or mid-flight-on-another-device —
 * session).
 *
 * Deliberately **route-free and split-free**, same reasoning the mobile
 * `CardioSummaryScreen` documents: GPS tracking doesn't exist anywhere in
 * the app before C4a, so no cardio session — live or logged — has a route
 * or splits to show yet. Building that rendering now would be guessing at a
 * polyline encoding C4a hasn't chosen.
 *
 * The metric tiles (`buildCardioTiles`) mirror the mobile
 * `CardioSummaryScreen._metricSections` field selection exactly, not the
 * W03 desktop mockup's full metric-grid + zones + splits, so the same
 * session shows the same fields on both platforms.
 */
export function CardioSessionDetail({ session }: { session: WorkoutSessionResponse }) {
  const t = useTranslations("workouts");
  const ta = useTranslations("workouts.activityTypes");
  const locale = useLocale();

  const activityType = session.activityType ?? "OTHER_CARDIO";
  const color = activityTypeColor(activityType);
  const tiles = buildCardioTiles(session, t, locale);

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
    </div>
  );
}
