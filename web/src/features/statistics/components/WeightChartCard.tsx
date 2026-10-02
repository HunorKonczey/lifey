"use client";

import { CartesianGrid, Line, LineChart, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { useTranslations } from "next-intl";
import { useFormat } from "@/lib/format/useFormat";
import { useReducedMotion } from "@/lib/hooks/useReducedMotion";
import { axisColumns } from "../chartAxis";
import type { PeriodStats } from "../periodStats";
import { ChartCard, ChartLegend, type LegendItem } from "./ChartCard";

const COLOR = "var(--m-weight)";

/**
 * "Testsúly" (W5.4): the measurements as a line with dots. A day without a weigh-in is a *gap*: the solid line
 * stops, but the two measurements either side of it are joined by a **dotted** segment so the eye can follow the
 * trend (a second series with `connectNulls`, drawn underneath; the solid series never bridges). The Y scale
 * follows the data; a goal too far away to fit stays off the chart and the footnote says where it is.
 */
export function WeightChartCard({ stats, compact = false }: { stats: PeriodStats; compact?: boolean }) {
  const t = useTranslations("statistics");
  const fmt = useFormat();
  const reduced = useReducedMotion();
  const { period, weight, slots } = stats;
  const columns = axisColumns(period, slots, fmt, t("todayShort"));

  const rows = slots.map((slot, i) => ({
    key: columns[i].key,
    axisLabel: columns[i].axisLabel,
    date: slot.start,
    value: weight.values[i],
    // The dotted twin: every measurement, joined across gaps.
    bridge: weight.values[i],
  }));
  const measured = rows.filter((r) => r.value != null);
  const lastKey = measured.length ? measured[measured.length - 1].key : null;
  const hasGap =
    measured.length >= 2 &&
    rows.slice(rows.indexOf(measured[0]), rows.indexOf(measured[measured.length - 1]) + 1).some((r) => r.value == null);

  const scale = weight.scale;
  const ticks = scale ? [scale.min, (scale.min + scale.max) / 2, scale.max] : undefined;
  const goalInside = weight.goal != null && scale != null && !weight.goalOutsideScale;

  const legend: LegendItem[] = [{ kind: "dot", color: COLOR, label: t("legendMeasurement") }];
  if (hasGap) legend.push({ kind: "dotted", color: COLOR, label: t("legendMissing") });
  if (goalInside) legend.push({ kind: "dashed", color: COLOR, label: t("legendWeightGoal", { goal: fmt.number(weight.goal!) }) });

  const footnote = [
    weight.goalOutsideScale && weight.goal != null && scale
      ? t(weight.goal < scale.min ? "goalBelowAxis" : "goalAboveAxis", { goal: fmt.number(weight.goal), scale: period })
      : null,
    hasGap ? t("missingDotted") : null,
  ]
    .filter(Boolean)
    .join(" ");

  function renderTick(props: { x?: number | string; y?: number | string; payload?: { value?: string } }) {
    const row = rows.find((r) => r.key === props.payload?.value);
    if (!row || row.axisLabel === "") return <g />;
    return (
      <text x={props.x} y={props.y} dy={12} textAnchor="middle" fontSize={12} fontWeight={500} fill="var(--text-3)">
        {row.axisLabel}
      </text>
    );
  }

  function renderDot(props: { cx?: number; cy?: number; payload?: { key: string; value: number | null } }) {
    if (props.payload?.value == null) return <g />;
    if (props.payload.key === lastKey) {
      return (
        <g>
          <circle cx={props.cx} cy={props.cy} r={8} fill="none" stroke="var(--card)" strokeWidth={4} />
          <circle cx={props.cx} cy={props.cy} r={6} fill={COLOR} />
        </g>
      );
    }
    return <circle cx={props.cx} cy={props.cy} r={4} fill={COLOR} stroke="var(--card)" strokeWidth={3} />;
  }

  return (
    <ChartCard
      testId="stats-weight"
      title={t("weight")}
      note={
        weight.latest != null && (
          <span>
            {fmt.weight(weight.latest)}
            {weight.goal != null ? ` · ${t("goalKg", { goal: fmt.number(weight.goal) })}` : ""}
          </span>
        )
      }
      footnote={footnote || undefined}
    >
      {scale && measured.length > 0 ? (
        <>
          <div role="img" aria-label={t("weightAria")}>
            <ResponsiveContainer width="100%" height={compact ? 180 : 220}>
              <LineChart data={rows} margin={{ top: 24, right: 16, bottom: 0, left: 0 }}>
                <CartesianGrid vertical={false} stroke="var(--grid)" />
                <YAxis
                  width={44}
                  ticks={ticks}
                  domain={[scale.min, scale.max]}
                  tickFormatter={(v: number) => fmt.number(v)}
                  axisLine={false}
                  tickLine={false}
                  tick={{ fontSize: 11, fill: "var(--text-3)" }}
                />
                <XAxis dataKey="key" axisLine={false} tickLine={false} interval={0} tick={renderTick} />
                <Tooltip
                  separator=""
                  cursor={false}
                  contentStyle={{ background: "var(--card)", border: "1px solid var(--hairline)", borderRadius: "var(--r-control)", fontSize: 12 }}
                  labelStyle={{ color: "var(--text-3)" }}
                  labelFormatter={(_, payload) => (payload?.[0]?.payload?.date ? fmt.shortDate(payload[0].payload.date as Date) : "")}
                  formatter={(v, name) => (name === "value" && typeof v === "number" ? [fmt.weight(v), ""] : [null, null]) as never}
                />
                {goalInside && <ReferenceLine y={weight.goal!} stroke={COLOR} strokeOpacity={0.7} strokeWidth={1.5} strokeDasharray="5 4" />}
                <Line
                  type="linear"
                  dataKey="bridge"
                  stroke={COLOR}
                  strokeWidth={2}
                  strokeDasharray="2 6"
                  strokeLinecap="round"
                  dot={false}
                  activeDot={false}
                  connectNulls
                  isAnimationActive={false}
                  legendType="none"
                  tooltipType="none"
                />
                <Line
                  type="linear"
                  dataKey="value"
                  stroke={COLOR}
                  strokeWidth={3}
                  strokeLinejoin="round"
                  strokeLinecap="round"
                  dot={renderDot}
                  activeDot={{ r: 5, fill: COLOR }}
                  connectNulls={false}
                  isAnimationActive={!reduced}
                  animationDuration={900}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
          <ChartLegend items={legend} />
        </>
      ) : (
        <p className="type-body-s text-center py-16" style={{ color: "var(--text-3)" }}>
          {t("noWeightEntries")}
        </p>
      )}
    </ChartCard>
  );
}
