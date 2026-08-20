import { useTranslations } from "next-intl";
import { formatTemperature, formatWindSpeed, formatPrecipitation } from "../cardioFormat";
import { weatherConditionIcon, weatherConditionLabelKey } from "../weatherCondition";

interface WeatherCardProps {
  condition: string | null;
  tempC: number | null;
  windKph: number | null;
  precipMm: number | null;
  /** ISO instant — the session's start time, shown as the snapshot's clock time. */
  startedAt: string;
}

/**
 * M42's "IDŐJÁRÁS INDULÁSKOR" card, HIKING-only (docs/cardio/60 §8 C8w.4) —
 * a manual, unconstrained snapshot (Q-C8.1: no weather API, no network
 * dependency). Unlike mobile's always-tappable version (which doubles as
 * the add-weather entry point, `_WeatherEmptyRow`), the web never edits
 * cardio (D-W.2) — so there's no empty-state row to render here at all,
 * only this card, and only when the caller confirms at least one of the
 * four fields is set. A missing individual field still reads "—" rather
 * than reflowing the layout, same as mobile.
 */
export function WeatherCard({ condition, tempC, windKph, precipMm, startedAt }: WeatherCardProps) {
  const t = useTranslations("workouts");
  const labelKey = condition ? weatherConditionLabelKey(condition) : null;
  const snapshotTime = new Date(startedAt).toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" });

  return (
    <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
      <div className="flex items-center justify-between mb-3">
        <p className="text-sm font-semibold" style={{ color: "var(--on-surface-variant)" }}>
          {t("cardioWeatherHeading")}
        </p>
        <p className="text-[10.5px] font-semibold" style={{ color: "var(--on-surface-variant)" }}>
          {t("cardioWeatherSnapshotCaption", { time: snapshotTime })}
        </p>
      </div>
      <div className="flex items-center gap-3">
        <div
          className="w-[52px] h-[52px] rounded-[18px] flex items-center justify-center flex-none"
          style={{ background: "color-mix(in srgb, var(--secondary) 14%, transparent)" }}
        >
          <span className="material-symbols-rounded text-[28px]" style={{ color: "var(--secondary)" }}>
            {weatherConditionIcon(condition)}
          </span>
        </div>
        <div className="flex-1 grid grid-cols-3 gap-2 min-w-0">
          <div>
            <p className="text-xl font-extrabold tabular" style={{ color: "var(--on-surface)" }}>
              {tempC != null ? formatTemperature(tempC) : "—"}
            </p>
            <p className="text-[9.5px] font-semibold" style={{ color: "var(--on-surface-variant)" }}>
              {t("cardioWeatherTemperatureLabel")}
            </p>
          </div>
          <div>
            <p className="text-xl font-extrabold tabular" style={{ color: "var(--on-surface)" }}>
              {windKph != null ? formatWindSpeed(windKph) : "—"}
            </p>
            <p className="text-[9.5px] font-semibold" style={{ color: "var(--on-surface-variant)" }}>
              {t("cardioWeatherWindLabel")}
            </p>
          </div>
          <div>
            <p className="text-xl font-extrabold tabular" style={{ color: "var(--on-surface)" }}>
              {precipMm != null ? formatPrecipitation(precipMm) : "—"}
            </p>
            <p className="text-[9.5px] font-semibold" style={{ color: "var(--on-surface-variant)" }}>
              {t("cardioWeatherPrecipLabel")}
            </p>
          </div>
        </div>
      </div>
      {condition && (
        <p className="text-xs font-semibold mt-3" style={{ color: "var(--on-surface-variant)" }}>
          {labelKey ? t(labelKey) : condition}
        </p>
      )}
    </div>
  );
}
