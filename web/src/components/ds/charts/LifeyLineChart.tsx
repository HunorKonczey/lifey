"use client";

import {
  CartesianGrid,
  Line,
  LineChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { useFormat } from "@/lib/format/useFormat";
import { useReducedMotion } from "@/lib/hooks/useReducedMotion";
import { movingAverage, type TimeSeriesPoint } from "./chartMath";

export interface LineChartPoint {
  date: Date;
  /** `null` = no data that day — a gap, never plotted as 0. */
  value: number | null;
  /** Overrides the auto-formatted `shortDate(date)` X-axis label — for a
   *  caller (`TimeSeriesChart`'s adapter) that already has its own
   *  pre-formatted label and no real per-point date to format. */
  label?: string;
}

export interface LifeyLineChartProps {
  data: LineChartPoint[];
  color: string;
  goal?: number;
  goalLabel?: string;
  unit?: string;
  height?: number;
  /** Draws the 7-day moving average alongside the raw points (D-W0.9). */
  showAverage?: boolean;
  /** "napi mérés" / "7 napos átlag" / "cél" — omit any to hide that legend entry. */
  legend?: { raw?: string; average?: string; goal?: string };
  "aria-label"?: string;
}

/** The exact midpoint between `min`/`max` (rounded up/down to whole numbers
 *  for headroom), unlike `chartMath.yAxisTicks`'s 0-anchored scale — a line
 *  chart's own value range (weight, not a zero-based count) needs its axis
 *  to span the data instead of starting at 0. Not a mobile port: no canvas
 *  equivalent names this specifically. */
function lineAxisTicks(dataMin: number, dataMax: number, goal?: number): [number, number, number] {
  const low = Math.min(dataMin, goal ?? dataMin);
  const high = Math.max(dataMax, goal ?? dataMax);
  const bottom = Math.floor(low);
  const top = Math.ceil(high);
  return [top, (top + bottom) / 2, bottom];
}

/**
 * DS-04's line chart (D-W0.9): a straight (`type="linear"`, never
 * `"monotone"` — no overshoot, no invented valley) line with gaps left as
 * gaps (`connectNulls={false}`), an optional 7-day moving average
 * (`chartMath.movingAverage`, gap-aware), a dashed goal reference line, and
 * the last real point emphasised (12px, a 4px `--card`-colour ring). Renders
 * a "no data" band instead of an empty axis when the whole range is empty.
 */
export function LifeyLineChart({
  data,
  color,
  goal,
  goalLabel,
  unit = "",
  height = 240,
  showAverage = false,
  legend,
  ...aria
}: LifeyLineChartProps) {
  const format = useFormat();
  const reduced = useReducedMotion();

  const hasData = data.some((d) => d.value != null);
  const values = data.filter((d): d is { date: Date; value: number } => d.value != null);

  if (!hasData) {
    const rangeLabel =
      data.length > 0 ? `${format.shortDate(data[0].date)} – ${format.shortDate(data[data.length - 1].date)}` : null;
    return (
      <div
        role="img"
        aria-label={aria["aria-label"]}
        className="flex items-center justify-center type-body-s"
        style={{ height, color: "var(--text-3)" }}
      >
        {rangeLabel ? `No data ${rangeLabel}` : "No data"}
      </div>
    );
  }

  const averageSeries: TimeSeriesPoint[] = values.map((p) => ({ date: p.date, value: p.value }));
  const averages = showAverage ? movingAverage(averageSeries) : [];
  const averageByTime = new Map(averageSeries.map((p, i) => [p.date.getTime(), averages[i] ?? null]));

  const chartData = data.map((p) => ({
    time: p.date.getTime(),
    label: p.label ?? format.shortDate(p.date),
    value: p.value,
    average: averageByTime.get(p.date.getTime()) ?? null,
  }));

  const lastIndex = data.reduce((acc, d, i) => (d.value != null ? i : acc), -1);
  const lastTime = lastIndex >= 0 ? data[lastIndex].date.getTime() : undefined;

  const dataMin = Math.min(...values.map((p) => p.value));
  const dataMax = Math.max(...values.map((p) => p.value));
  const [top, mid, bottom] = lineAxisTicks(dataMin, dataMax, goal);

  function renderLastDot(props: { cx?: number; cy?: number; payload?: { time: number } }) {
    if (props.payload?.time !== lastTime) return <g />;
    return (
      <g>
        <circle cx={props.cx} cy={props.cy} r={8} fill="none" stroke="var(--card)" strokeWidth={4} />
        <circle cx={props.cx} cy={props.cy} r={6} fill={color} />
      </g>
    );
  }

  return (
    <div style={{ width: "100%" }} role="img" aria-label={aria["aria-label"]}>
      <ResponsiveContainer width="100%" height={height}>
        <LineChart data={chartData} margin={{ top: 24, right: 16, bottom: 0, left: 0 }}>
          <CartesianGrid vertical={false} stroke="var(--grid)" />
          <YAxis
            width={44}
            tickCount={3}
            ticks={[bottom, mid, top]}
            domain={[bottom, top]}
            tickFormatter={(v: number) => format.compactAxis(v)}
            axisLine={false}
            tickLine={false}
            tick={{ fontSize: 11, fill: "var(--text-3)" }}
          />
          <XAxis
            dataKey="label"
            axisLine={false}
            tickLine={false}
            interval="preserveStartEnd"
            tick={{ fontSize: 11, fill: "var(--text-3)" }}
          />
          <Tooltip
            // The series has no name, so Recharts' default ": " separator
            // would render a stray leading colon.
            separator=""
            contentStyle={{
              background: "var(--card)",
              border: "1px solid var(--hairline)",
              borderRadius: "var(--r-control)",
              fontSize: 12,
            }}
            labelStyle={{ color: "var(--text-3)" }}
            formatter={(v) => [typeof v === "number" ? `${v.toLocaleString(format.locale)}${unit}` : `${v}${unit}`, ""] as [string, string]}
          />
          {goal != null && (
            <ReferenceLine
              y={goal}
              stroke={color}
              strokeOpacity={0.7}
              strokeWidth={1.5}
              strokeDasharray="5 4"
              label={{ value: goalLabel, position: "insideTopRight", fill: color, fillOpacity: 0.7, fontSize: 11 }}
            />
          )}
          {showAverage && (
            <Line
              type="linear"
              dataKey="average"
              stroke={color}
              strokeOpacity={0.45}
              strokeWidth={2}
              strokeDasharray="4 3"
              dot={false}
              connectNulls={false}
              isAnimationActive={!reduced}
              animationDuration={900}
            />
          )}
          <Line
            type="linear"
            dataKey="value"
            stroke={color}
            strokeWidth={3}
            dot={renderLastDot}
            activeDot={{ r: 5, fill: color }}
            connectNulls={false}
            isAnimationActive={!reduced}
            animationDuration={900}
          />
        </LineChart>
      </ResponsiveContainer>
      {legend && (legend.raw || legend.average || legend.goal) && (
        <p className="type-body-s text-center mt-1" style={{ color: "var(--text-3)" }}>
          {[legend.raw, showAverage ? legend.average : null, goal != null ? legend.goal : null].filter(Boolean).join(" · ")}
        </p>
      )}
    </div>
  );
}
