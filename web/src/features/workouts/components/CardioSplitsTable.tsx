import { useTranslations, useLocale } from "next-intl";
import type { ReactNode } from "react";
import { formatDistanceKm, formatPace, formatDuration, formatElevationDelta } from "../cardioFormat";
import type { CardioSplitResponse, IntervalIntensity } from "../types";

interface CardioSplitsTableProps {
  splits: CardioSplitResponse[];
  /** Rendered above the table, inside the same card/heading (docs/cardio/60 §8 C6w.3's `PaceBarChart`). */
  chart?: ReactNode;
  /** Colors the interval intensity bar (docs/cardio/60 §8 C7w.1) — unused on the DISTANCE path. */
  accent?: string;
}

/** Mobile's `_IntervalSectionRow` fractions: hard bars fill, easier ones are shorter and dimmer. */
const INTENSITY_FRACTION: Record<IntervalIntensity, number> = { EASY: 0.35, MODERATE: 0.65, HARD: 1 };
const INTENSITY_LABEL_KEY: Record<IntervalIntensity, string> = {
  EASY: "cardioIntervalIntensityEasy",
  MODERATE: "cardioIntervalIntensityModerate",
  HARD: "cardioIntervalIntensityHard",
};

/**
 * Read-only split table — the web counterpart of the mobile split-list
 * (docs/cardio/60 §2.1 Q-D1: distance + pace + elevation, **no heart rate**,
 * same depth decision, same reasoning applies at table-row width).
 *
 * The elevation column only appears if *any* split carries elevation data
 * (mirrors the mobile C6.4 rule: "a kártya egyszer mondja ki, nem soronként
 * üres oszlop") — no column of blank dashes for a session with no altimeter.
 *
 * **`INTERVAL` splits (docs/cardio/60 §8 C7w.1)** get a different row shape
 * entirely — distance and pace aren't concepts for an interval section, so
 * the table switches its whole header/row layout to intensity + duration (+
 * watts) whenever *any* split in the list is `INTERVAL`-typed, the same way
 * mobile's M39 "INTERVALLUM-SZAKASZOK" card is a different card from M33's
 * split list, not the same card with a different row here and there. A
 * `DISTANCE` split mixed into an interval-mode table (never happens in
 * practice today — one session produces exactly one split type — but the
 * kész-ha calls for correct rendering either way) falls back to showing its
 * own distance and duration rather than crashing or lying. The all-DISTANCE
 * path below is byte-for-byte what shipped in W0w.3/C6w.1 — untouched.
 */
export function CardioSplitsTable({ splits, chart, accent = "var(--primary)" }: CardioSplitsTableProps) {
  const t = useTranslations("workouts");
  const locale = useLocale();

  if (splits.length === 0) return null;

  const sorted = [...splits].sort((a, b) => a.splitIndex - b.splitIndex);
  const hasInterval = sorted.some((s) => s.splitType === "INTERVAL");

  if (hasInterval) {
    const hasWatts = sorted.some((s) => s.avgWatts != null);
    return (
      <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
        <div className="flex items-center justify-between mb-3">
          <p className="text-sm font-semibold" style={{ color: "var(--on-surface-variant)" }}>
            {t("cardioIntervalSectionsHeading")}
          </p>
          <span
            className="px-2 py-0.5 rounded-[var(--r-pill)] text-xs font-bold"
            style={{ background: `color-mix(in srgb, ${accent} 16%, transparent)`, color: accent }}
          >
            {t("cardioIntervalSectionsCountChip", { count: sorted.length })}
          </span>
        </div>
        {chart && <div className="mb-3">{chart}</div>}
        <table className="w-full text-sm tabular">
          <thead>
            <tr style={{ color: "var(--muted)" }}>
              <th className="text-left font-semibold pb-2">{t("cardioSplitIndexHeader")}</th>
              <th className="text-left font-semibold pb-2">{t("cardioIntervalIntensityHeader")}</th>
              <th className="text-right font-semibold pb-2">{t("cardioIntervalDurationHeader")}</th>
              {hasWatts && <th className="text-right font-semibold pb-2">{t("cardioIntervalWattsHeader")}</th>}
            </tr>
          </thead>
          <tbody>
            {sorted.map((split) => {
              const intensity = split.intensity;
              const fraction = intensity ? INTENSITY_FRACTION[intensity] : null;
              const hard = intensity === "HARD";
              return (
                <tr key={split.splitIndex} style={{ borderTop: "1px solid var(--surface-container)" }}>
                  <td className="py-1.5" style={{ color: "var(--on-surface-variant)" }}>
                    {split.splitIndex + 1}
                  </td>
                  <td className="py-1.5">
                    {split.splitType === "INTERVAL" && intensity ? (
                      <div className="flex items-center gap-2">
                        <span
                          className="w-16 flex-none truncate text-xs font-bold"
                          style={{ color: hard ? accent : "var(--on-surface-variant)" }}
                        >
                          {t(INTENSITY_LABEL_KEY[intensity])}
                        </span>
                        <span className="flex-1 h-2.5 rounded-[5px] overflow-hidden" style={{ background: "var(--surface-highest)" }}>
                          <span
                            className="block h-full rounded-[5px]"
                            style={{ width: `${(fraction ?? 0) * 100}%`, background: accent, opacity: hard ? 1 : fraction ?? 1 }}
                          />
                        </span>
                      </div>
                    ) : (
                      <span style={{ color: "var(--on-surface)" }}>
                        {split.distanceMeters != null ? formatDistanceKm(split.distanceMeters, locale) : "—"}
                      </span>
                    )}
                  </td>
                  <td className="py-1.5 text-right font-bold tabular" style={{ color: "var(--on-surface)" }}>
                    {formatDuration(split.durationSeconds)}
                  </td>
                  {hasWatts && (
                    <td className="py-1.5 text-right" style={{ color: "var(--on-surface-variant)" }}>
                      {split.avgWatts != null ? `${Math.round(split.avgWatts)} W` : "—"}
                    </td>
                  )}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    );
  }

  const hasElevation = sorted.some((s) => s.elevationDeltaM != null);

  return (
    <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
      <p className="text-sm font-semibold mb-3" style={{ color: "var(--on-surface-variant)" }}>
        {t("cardioSplitsHeading")}
      </p>
      {chart && <div className="mb-3">{chart}</div>}
      <table className="w-full text-sm tabular">
        <thead>
          <tr style={{ color: "var(--muted)" }}>
            <th className="text-left font-semibold pb-2">{t("cardioSplitIndexHeader")}</th>
            <th className="text-left font-semibold pb-2">{t("cardioSplitDistanceHeader")}</th>
            <th className="text-right font-semibold pb-2">{t("cardioSplitPaceHeader")}</th>
            {hasElevation && <th className="text-right font-semibold pb-2">{t("cardioSplitElevationHeader")}</th>}
          </tr>
        </thead>
        <tbody>
          {sorted.map((split) => {
            const pace =
              split.distanceMeters != null ? formatPace(split.distanceMeters, split.durationSeconds) : null;
            return (
              <tr key={split.splitIndex} style={{ borderTop: "1px solid var(--surface-container)" }}>
                <td className="py-1.5" style={{ color: "var(--on-surface-variant)" }}>
                  {split.splitIndex + 1}
                </td>
                <td className="py-1.5" style={{ color: "var(--on-surface)" }}>
                  {split.distanceMeters != null ? formatDistanceKm(split.distanceMeters, locale) : "—"}
                </td>
                <td className="py-1.5 text-right" style={{ color: "var(--on-surface)" }}>
                  {pace ?? "—"}
                </td>
                {hasElevation && (
                  <td className="py-1.5 text-right" style={{ color: "var(--on-surface-variant)" }}>
                    {split.elevationDeltaM != null ? formatElevationDelta(split.elevationDeltaM) : "—"}
                  </td>
                )}
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
