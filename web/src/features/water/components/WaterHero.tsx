"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Button, Card, Icon, NumberField } from "@/components/ds";
import { ProgressRing } from "@/components/ds/progress";
import { useFormat } from "@/lib/format/useFormat";
import type { QuickSource } from "../quickSources";
import { containersLeft } from "../waterStats";

const WATER = "var(--metric-water)";

export interface WaterTile {
  source: QuickSource;
  /** "Pohár", "Tea", … — a saved source's own name, or the default container's. */
  name: string;
}

/**
 * The water page's hero (W4.5, W4-B, client-021): the ring with the percentage, "1,6 / 2,5 L", "Még 0,9 L · kb. 4
 * pohár" (what is left in units of the usual container), four big source tiles that log an entry on a tap ("＋0,25 L ·
 * Pohár"), an amount of your own, and "Vízforrások kezelése" (the sources drawer).
 */
export function WaterHero({
  total,
  goal,
  tiles,
  containerLiters,
  pending,
  onAdd,
  onManage,
}: {
  total: number;
  goal: number;
  tiles: WaterTile[];
  /** Volume of the most used source — the unit of "kb. 4 pohár". */
  containerLiters: number;
  pending: boolean;
  onAdd: (source: QuickSource) => void;
  onManage: () => void;
}) {
  const t = useTranslations("water");
  const fmt = useFormat();
  const [custom, setCustom] = useState(0.35);
  const progress = goal > 0 ? total / goal : 0;
  const remaining = Math.max(0, Math.round((goal - total) * 1000) / 1000);
  const left = containersLeft(remaining, containerLiters);

  return (
    <Card className="flex flex-col gap-5" data-testid="water-hero">
      <div className="flex items-center gap-5">
        <ProgressRing progress={progress} color={WATER} size={148} aria-label={t("ringAria", { percent: Math.round(progress * 100) })}>
          <span className="tabular" style={{ fontSize: 30, fontWeight: 800, letterSpacing: "-0.02em" }} data-testid="water-percent">
            {Math.round(progress * 100)} %
          </span>
        </ProgressRing>
        <div className="min-w-0">
          <p className="tabular" style={{ fontSize: 30, fontWeight: 800, letterSpacing: "-0.02em" }} data-testid="water-amount">
            {fmt.litresOfGoal(total, goal)}
          </p>
          <p className="type-body-s mt-1" style={{ color: "var(--text-2)" }} data-testid="water-remaining">
            {remaining <= 0 ? t("goalReached") : t("remaining", { litres: fmt.litres(remaining), count: left })}
          </p>
        </div>
      </div>

      <div className="flex flex-col gap-2">
        <span className="type-section" style={{ color: "var(--text-3)" }}>
          {t("quickAdd")}
        </span>
        <div className="grid grid-cols-2 gap-2" data-testid="water-tiles">
          {tiles.map(({ source: s, name }, i) => (
            <button
              key={`${s.sourceId ?? "d"}-${s.volumeLiters}-${i}`}
              type="button"
              onClick={() => onAdd(s)}
              disabled={pending}
              className="lifey-button flex flex-col items-start gap-0.5 p-3 text-left disabled:opacity-50"
              style={{ borderRadius: "var(--r-card)", background: "color-mix(in srgb, var(--metric-water) var(--chip-tint), transparent)" }}
            >
              <span className="type-title-s tabular" style={{ color: WATER }}>
                +{fmt.litres(s.volumeLiters)}
              </span>
              <span className="type-body-s" style={{ color: "var(--text-2)" }}>
                {name}
              </span>
            </button>
          ))}
        </div>
      </div>

      <div className="flex items-end gap-2">
        <NumberField
          className="flex-1"
          label={t("customAmount")}
          value={custom}
          onChange={setCustom}
          unit="L"
          step={0.05}
          min={0.05}
          max={5}
          maxDecimals={2}
          onEnter={(v) => onAdd({ sourceId: null, volumeLiters: v })}
        />
        <Button variant="secondary" onClick={() => onAdd({ sourceId: null, volumeLiters: custom })} disabled={pending}>
          <Icon name="add" size={20} />
          {t("add")}
        </Button>
      </div>

      <div>
        <Button variant="ghost" onClick={onManage}>
          <Icon name="tune" size={20} />
          {t("manageSources")}
        </Button>
      </div>
    </Card>
  );
}
