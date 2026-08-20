import { useTranslations } from "next-intl";
import { formatDuration } from "../cardioFormat";
import type { HrZoneBreakdown, HrZoneIntensity } from "../hrZoneBreakdown";

/**
 * Cool-to-warm ramp, one step per zone — the web port of mobile's
 * `HrZonePanel._zoneColors`. Local to this component rather than a design
 * token: these five are only ever used together, as a scale, unlike the
 * `--metric-*` tokens which are each an identity for one metric.
 */
const ZONE_COLORS = ["#6E8FA8", "#5FA88C", "#D8B35A", "#D98A4E", "#C4564E"];

const ZONE_NAME_KEYS = ["hrZone1Name", "hrZone2Name", "hrZone3Name", "hrZone4Name", "hrZone5Name"];

const VERDICT_KEY: Record<HrZoneIntensity, string> = {
  hard: "hrZoneVerdictHard",
  balanced: "hrZoneVerdictBalanced",
  easy: "hrZoneVerdictEasy",
};

interface HrZonePanelProps {
  breakdown: HrZoneBreakdown;
}

/**
 * M43's heart-rate zone panel: a stacked bar, a verdict chip, and one row
 * per zone (docs/cardio/60 §8 C9w.1) — the web port of the mobile
 * `HrZonePanel`. **One component for every cardio type** (Q-D7); only where
 * the caller places it in the page differs by family.
 *
 * Two accessibility rules carried over from the frame, both load-bearing:
 * - the verdict is **said in words** in the header chip — the bar's colours
 *   alone are not readable by a colour-blind reader;
 * - **the numbers stay full contrast** — colour appears only on the zone
 *   code chip and the small per-row bar, never on the time or percentage.
 */
export function HrZonePanel({ breakdown }: HrZonePanelProps) {
  const t = useTranslations("workouts");
  const verdictColor = ZONE_COLORS[breakdown.intensity === "hard" ? 4 : 2];

  return (
    <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
      <div className="flex items-center justify-between mb-3">
        <p className="text-[11px] font-bold tracking-wide" style={{ color: "var(--on-surface-variant)" }}>
          {t("hrZonesSectionLabel").toUpperCase()}
        </p>
        <span
          className="flex items-center gap-1 px-2.5 py-1 rounded-[var(--r-pill)] text-xs font-extrabold"
          style={{ background: `color-mix(in srgb, ${verdictColor} 16%, transparent)`, color: "var(--on-surface)" }}
        >
          <span className="material-symbols-rounded text-xs" style={{ color: verdictColor }}>
            local_fire_department
          </span>
          {t(VERDICT_KEY[breakdown.intensity])}
        </span>
      </div>

      <div className="flex h-[22px] rounded-[6px] overflow-hidden">
        {breakdown.slices.map(
          (slice, i) =>
            slice.fraction > 0 && (
              <div
                key={slice.zone}
                style={{
                  width: `${slice.fraction * breakdown.coverageFraction * 100}%`,
                  background: ZONE_COLORS[i],
                }}
              />
            ),
        )}
        {breakdown.isPartial && (
          <div
            style={{
              width: `${(1 - breakdown.coverageFraction) * 100}%`,
              background: "color-mix(in srgb, var(--outline) 35%, transparent)",
              backgroundImage:
                "repeating-linear-gradient(45deg, var(--outline) 0, var(--outline) 1px, transparent 1px, transparent 6px)",
            }}
          />
        )}
      </div>
      <div className="flex justify-between mt-1.5 text-[10px]" style={{ color: "var(--outline)" }}>
        <span>{t("hrZoneEasyEndLabel")}</span>
        <span>{t("hrZoneHardEndLabel")}</span>
      </div>

      {breakdown.isPartial && (
        <div className="flex items-center gap-1.5 mt-2.5 text-[10.5px]" style={{ color: "var(--outline)" }}>
          <span className="material-symbols-rounded text-xs">timelapse</span>
          {t("hrZonePartialCoverage", { percent: Math.round(breakdown.coverageFraction * 100) })}
        </div>
      )}

      <div className="flex flex-col gap-2.5 mt-3.5">
        {breakdown.slices.map((slice, i) => {
          const empty = slice.seconds <= 0;
          const color = ZONE_COLORS[i];
          return (
            <div key={slice.zone} className="flex items-center gap-2">
              <span
                className="w-6 flex-none text-center text-[10px] font-extrabold py-0.5 rounded-[5px]"
                style={{
                  background: `color-mix(in srgb, ${color} ${empty ? 10 : 22}%, transparent)`,
                  color: empty ? "var(--outline)" : "var(--on-surface)",
                }}
              >
                Z{slice.zone}
              </span>
              <span
                className="w-[74px] flex-none text-[11.5px] truncate"
                style={{ color: empty ? "var(--outline)" : "var(--on-surface-variant)" }}
              >
                {t(ZONE_NAME_KEYS[i])}
              </span>
              <span className="flex-1 h-2 rounded-[4px] overflow-hidden" style={{ background: "var(--surface-container)" }}>
                <span
                  className="block h-full rounded-[4px]"
                  style={{ width: `${Math.min(1, slice.fraction) * 100}%`, background: color }}
                />
              </span>
              <span
                className="w-11 flex-none text-right text-xs font-extrabold tabular"
                style={{ color: empty ? "var(--outline)" : "var(--on-surface)" }}
              >
                {formatDuration(slice.seconds)}
              </span>
              <span
                className="w-9 flex-none text-right text-[11px] font-bold tabular"
                style={{ color: empty ? "var(--outline)" : "var(--on-surface-variant)" }}
              >
                {Math.round(slice.fraction * 100)}%
              </span>
            </div>
          );
        })}
      </div>

      <p className="text-[10px] leading-snug mt-3" style={{ color: "var(--outline)" }}>
        {t("hrZoneSourceNote")}
      </p>
    </div>
  );
}
