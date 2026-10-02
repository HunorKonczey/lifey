"use client";

import { useState } from "react";
import { useLocale, useTranslations } from "next-intl";
import { Card } from "@/components/ds";
import { formatDuration } from "../cardioFormat";
import { PaceBarGeometry } from "../paceBarGeometry";
import { buildPaceBars } from "../paceBars";
import type { CardioSplitResponse } from "../types";

const WIDTH = 480;
const HEIGHT = 170;
/** Room left of the bars for the Y-axis labels. */
const AXIS_W = 34;

interface PaceBarChartProps {
  splits: CardioSplitResponse[];
}

/**
 * "Kilométerenként · leggyorsabb 5:32 · 3. km" (W3.10, W3-D, client-013): per-split pace as bars, **taller =
 * faster**, with a pace Y axis (5:30 / 6:00 / 6:30), a dashed average line labelled with its pace, the **fastest**
 * kilometre in full heart colour and the others at 35 %, and the last partial kilometre drawn in proportion to its
 * length and labelled with it ("0,2"). Web port of the mobile `PaceBarChart`; clicking a bar only highlights it.
 * Renders nothing under two bars — one split has no pace to compare.
 */
export function PaceBarChart({ splits }: PaceBarChartProps) {
  const t = useTranslations("workouts");
  const locale = useLocale();
  const [selectedIndex, setSelectedIndex] = useState<number | null>(null);
  const bars = buildPaceBars(splits, locale);
  if (bars.length < 2) return null;

  const plotW = WIDTH - AXIS_W;
  const geometry = new PaceBarGeometry(bars, plotW, HEIGHT);
  const averageY = geometry.averageLineY;
  const averageSeconds = geometry.averageSeconds;
  const fastestIndex = geometry.fastestIndex;
  const radius = Math.min(7, geometry.barWidth / 2);

  return (
    <Card data-testid="pace-chart">
      <div className="mb-3 flex flex-wrap items-baseline justify-between gap-x-3">
        <h3 className="type-title-s">{t("paceChartTitle")}</h3>
        {fastestIndex != null && (
          <p className="type-body-s tabular" style={{ color: "var(--text-2)" }} data-testid="pace-fastest">
            {t("paceFastest", { pace: bars[fastestIndex].label, n: fastestIndex + 1 })}
          </p>
        )}
      </div>

      <svg viewBox={`0 0 ${WIDTH} ${HEIGHT}`} className="h-auto w-full" role="img" aria-label={t("paceChartAria")}>
        {geometry.axisTicks().map((tick) => (
          <g key={tick.seconds}>
            <line x1={AXIS_W} x2={WIDTH} y1={tick.y} y2={tick.y} stroke="var(--hairline)" strokeWidth={1} />
            <text x={AXIS_W - 6} y={tick.y + 3} textAnchor="end" fontSize={10} fill="var(--text-3)">
              {formatDuration(tick.seconds)}
            </text>
          </g>
        ))}

        <g transform={`translate(${AXIS_W} 0)`}>
          {averageY != null && averageSeconds != null && (
            <>
              <line x1={0} y1={averageY} x2={plotW} y2={averageY} stroke="var(--text-3)" strokeWidth={1} strokeDasharray="3 5" />
              <text x={plotW} y={averageY - 4} textAnchor="end" fontSize={10} fontWeight={700} fill="var(--text-2)" data-testid="pace-average">
                {formatDuration(Math.round(averageSeconds))}
              </text>
            </>
          )}

          {bars.map((bar, i) => {
            const rect = geometry.barRect(i);
            const fastest = i === fastestIndex;
            const selected = i === selectedIndex;
            return (
              <g key={i}>
                <rect
                  data-testid="pace-bar"
                  data-fastest={fastest || undefined}
                  data-partial={bar.partial || undefined}
                  x={rect.x}
                  y={rect.y}
                  width={rect.width}
                  height={rect.height}
                  rx={radius}
                  fill={bar.partial ? "var(--text-3)" : "var(--heart)"}
                  fillOpacity={fastest || selected ? 1 : bar.partial ? 0.35 : 0.35}
                  className="cursor-pointer"
                  onClick={() => setSelectedIndex(selectedIndex === i ? null : i)}
                />
                {bar.partial && bar.partialLabel && (
                  <text x={rect.x + rect.width / 2} y={rect.y - 4} textAnchor="middle" fontSize={9} fontWeight={700} fill="var(--text-3)">
                    {bar.partialLabel}
                  </text>
                )}
              </g>
            );
          })}

          {fastestIndex != null && (
            <text
              x={geometry.barRect(fastestIndex).x + geometry.barRect(fastestIndex).width / 2}
              y={Math.max(9, geometry.barRect(fastestIndex).y - 4)}
              textAnchor="middle"
              fontSize={10}
              fontWeight={800}
              fill="var(--heart)"
            >
              {bars[fastestIndex].label}
            </text>
          )}
        </g>
      </svg>
    </Card>
  );
}
