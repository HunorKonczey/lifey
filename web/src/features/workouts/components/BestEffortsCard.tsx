import { useTranslations } from "next-intl";
import { formatDuration } from "../cardioFormat";
import { buildBestEffortRows } from "../bestEfforts";
import type { BestEffortDistance } from "../cardioBestEffortRecords";
import type { CardioDetailsResponse } from "../types";

interface BestEffortsCardProps {
  cardio: CardioDetailsResponse;
  /** Which distances this session set a new personal best for (docs/cardio/60 §8 C6w.4). */
  records?: ReadonlySet<BestEffortDistance>;
}

/** Same amber the mobile M34 tile uses for its record row (`_BestEffortTile._amber`). */
const AMBER = "#D8B35A";

/**
 * Read-only "best efforts" card (docs/cardio/60 M34) — the web counterpart of
 * the mobile `CardioSummaryScreen._bestEffortSection`. Mirrors its behavior
 * exactly, not just its data: computed for the whole `DISTANCE` family
 * (RUNNING/WALKING/HIKING — `computeBestEfforts` in `cardio_session_screen.dart`
 * isn't RUNNING-only), and a distance the session never reached **doesn't
 * appear at all**, not greyed and not "not enough distance" — on a 4 km run
 * the 10 km best effort isn't missing data, it's not a concept. That falls
 * out of `best10kSeconds` being null, never 0.
 *
 * `records` (docs/cardio/60 §8 C6w.4) draws the same amber wash + border +
 * "record" pill as the mobile M34 tile. Cardio PRs have no server-side
 * storage — the caller derives `records` from `detectBestEffortRecords`,
 * which recomputes it from the session list already fetched to render the
 * page, the same way mobile computes it once from local history.
 */
export function BestEffortsCard({ cardio, records }: BestEffortsCardProps) {
  const t = useTranslations("workouts");
  const rows = buildBestEffortRows(cardio, records);

  if (rows.length === 0) return null;

  return (
    <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
      <p className="text-sm font-semibold mb-3" style={{ color: "var(--on-surface-variant)" }}>
        {t("cardioBestEffortsHeading")}
      </p>
      <div className="flex flex-col gap-3">
        {rows.map((row) => (
          <div
            key={row.labelKey}
            className="flex items-center gap-3 rounded-[var(--r-sm)] px-3 py-2 -mx-3"
            style={row.isRecord ? {
              background: "color-mix(in srgb, " + AMBER + " 12%, transparent)",
              border: "1px solid color-mix(in srgb, " + AMBER + " 34%, transparent)",
            } : undefined}
          >
            <div className="flex-1 min-w-0">
              <p className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>
                {t(row.labelKey)}
              </p>
              <p className="text-lg font-extrabold tabular" style={{ color: "var(--on-surface)" }}>
                {formatDuration(row.seconds)}
              </p>
              <div className="flex items-center gap-2">
                <p className="text-xs" style={{ color: "var(--muted)" }}>{t("cardioBestEffortSubtitle")}</p>
                {row.isRecord && (
                  <span
                    className="px-1.5 py-0.5 rounded-[var(--r-pill)] text-[10px] font-extrabold"
                    style={{ background: AMBER, color: "#161611" }}
                  >
                    {t("cardioRecordBadge")}
                  </span>
                )}
              </div>
            </div>
            {row.pace && (
              <span
                className="text-sm font-bold tabular flex-none"
                style={{ color: row.isRecord ? AMBER : "var(--on-surface-variant)" }}
              >
                {row.pace}
              </span>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
