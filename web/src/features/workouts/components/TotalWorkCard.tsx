import { useTranslations } from "next-intl";

interface TotalWorkCardProps {
  totalWorkKj: number;
  avgWatts: number;
  maxWatts: number | null;
  accent: string;
}

/**
 * M39's hero: the work actually done, derived from average power and the
 * time it was held (`cardioFormat.ts#totalWorkKj`, docs/cardio/60 §8 C7w.2)
 * — the web port of the mobile `_TotalWorkCard`. **Never stored**, so it can
 * never disagree with the two numbers beside it. Only ever rendered by the
 * caller when `totalWorkKj` is non-null — a machine that doesn't report
 * watts shows nothing here rather than a misleading 0 kJ.
 *
 * Unlike mobile, this doesn't take over the "hero" slot above the metric
 * grid — the web page always renders a uniform tile grid first (its own
 * established layout), and this card sits below it like every other
 * family-specific card. The data is identical; only the page position
 * differs from mobile's swap-the-hero layout.
 */
export function TotalWorkCard({ totalWorkKj, avgWatts, maxWatts, accent }: TotalWorkCardProps) {
  const t = useTranslations("workouts");

  return (
    <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--card)" }}>
      <div className="flex items-start gap-4">
        <div className="flex-1 min-w-0">
          <span aria-hidden="true" className="material-symbols-rounded text-lg" style={{ color: accent }}>
            bolt
          </span>
          <p className="text-[32px] font-extrabold tabular leading-tight" style={{ color: "var(--text)" }}>
            {totalWorkKj}
          </p>
          <p className="text-xs font-bold" style={{ color: "var(--text)" }}>
            kJ {t("cardioTotalWorkLabel")}
          </p>
          <p className="text-[11px]" style={{ color: "var(--text-2)" }}>
            {t("cardioTotalWorkSourceHint")}
          </p>
        </div>
        <div className="flex-1 min-w-0">
          <span aria-hidden="true" className="material-symbols-rounded text-lg" style={{ color: "var(--text-2)" }}>
            speed
          </span>
          <p className="text-[32px] font-extrabold tabular leading-tight" style={{ color: "var(--text)" }}>
            {Math.round(avgWatts)}
          </p>
          <p className="text-xs font-bold" style={{ color: "var(--text)" }}>
            {t("cardioAvgWattsLabel")}
          </p>
          {maxWatts != null && (
            <p className="text-[11px]" style={{ color: "var(--text-2)" }}>
              {t("cardioMaxWattsShortLabel", { watts: Math.round(maxWatts) })}
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
