"use client";

import {
  Bar,
  BarChart,
  CartesianGrid,
  ReferenceLine,
  ResponsiveContainer,
  XAxis,
  YAxis,
  type LabelProps,
} from "recharts";
import { useFormat } from "@/lib/format/useFormat";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { useReducedMotion } from "@/lib/hooks/useReducedMotion";
import { useTheme } from "@/lib/hooks/useTheme";
import { yAxisTicks } from "./chartMath";

export interface BarChartDatum {
  /** X-axis label — a weekday letter or a date. */
  label: string;
  /** `null` = no data for that slot — drawn as an empty column. */
  value: number | null;
  /** Full colour, dashed outline, no fill, and excluded from the caller's
   *  own average calculation (D-W0.9) — the current, still-accumulating day. */
  isToday?: boolean;
  /** Draws a small check glyph above the bar (e.g. a step-goal day met). */
  metGoal?: boolean;
  /** An optional label drawn above the bar (e.g. a cardio distance). */
  valueLabel?: string;
  /** No bar — a small dot sits on the axis instead (e.g. a rest day). */
  isRestDay?: boolean;
  /** Drawn at 45 % instead of the usual past-bar opacity — the days that did *not* reach the goal in the water chart (W4.5). */
  dimmed?: boolean;
  /** Read by screen readers instead of the raw value, e.g. "Monday, 1,680 kcal". */
  semanticsLabel?: string;
}

export interface LifeyBarChartProps {
  data: BarChartDatum[];
  color: string;
  goal?: number;
  goalLabel?: string;
  integer?: boolean;
  /** Formats the three Y-axis labels — for a small-number metric (litres) the default whole-number form would read 3 / 1 / 0. */
  yFormat?: (value: number) => string;
  /** The top of the Y axis, when the two-significant-digit default ("4,1") is not a number worth labelling (litres: 5). */
  yMax?: number;
  height?: number;
  /** e.g. "Average 1,812 kcal without today" — shown under the chart. */
  legend?: string;
  "aria-label"?: string;
}

interface BarShapeProps {
  x?: number;
  y?: number;
  width?: number;
  height?: number;
  payload?: BarChartDatum;
}

/**
 * DS-04's bar chart (D-W0.9): today is a dashed, unfilled outline (excluded
 * from the caller's own average — see `chartMath.averageExcludingPartialToday`),
 * past bars are the metric colour at 60% (dark) / 80% (light), a dashed goal
 * reference line, and a Y axis of exactly three ticks (top / half / 0) from
 * `chartMath.yAxisTicks`. A rest day (no bar) draws a small dot on the axis
 * instead of an empty column.
 */
export function LifeyBarChart({ data, color, goal, goalLabel, integer, yFormat, yMax, height = 220, legend, ...aria }: LifeyBarChartProps) {
  const format = useFormat();
  const reduced = useReducedMotion();
  const isDark = useIsDarkTheme();

  const dataMax = Math.max(0, ...data.map((d) => d.value ?? 0));
  const [top] = yMax != null ? [yMax] : yAxisTicks(dataMax, { goal, integer });
  const pastOpacity = isDark ? 0.6 : 0.8;

  function renderBar(props: BarShapeProps) {
    const { x = 0, y = 0, width = 0, height: h = 0, payload } = props;
    if (!payload || payload.value == null) return <g />;
    if (payload.isRestDay) {
      return <circle cx={x + width / 2} cy={y} r={3} fill="var(--text-3)" />;
    }
    const shape = payload.isToday ? (
      <rect x={x} y={y} width={width} height={h} rx={6} ry={6} fill="none" stroke={color} strokeWidth={2} strokeDasharray="4 3" />
    ) : (
      <rect x={x} y={y} width={width} height={h} rx={6} ry={6} fill={color} opacity={payload.dimmed ? 0.45 : pastOpacity} />
    );
    return (
      <g>
        {shape}
        {payload.metGoal && (
          // Drawn as SVG — an icon-font <span> inside an <svg> is never rendered (W4.6: the ✓ over a goal day was invisible).
          <g transform={`translate(${x + width / 2}, ${y - 12})`} data-testid="goal-check">
            <circle r={8} fill={color} />
            <path d="M-3.6 0.2 L-1.1 2.8 L3.8 -2.6" fill="none" stroke="var(--card)" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
          </g>
        )}
        {payload.valueLabel && (
          <text x={x + width / 2} y={y - 6} textAnchor="middle" fontSize={11} fill="var(--text-3)">
            {payload.valueLabel}
          </text>
        )}
      </g>
    );
  }

  function renderTick(props: LabelProps & { payload?: { value?: string } }) {
    const label = props.payload?.value ?? "";
    const isToday = data.find((d) => d.label === label)?.isToday;
    return (
      <text
        x={props.x}
        y={props.y}
        dy={12}
        textAnchor="middle"
        fontSize={12}
        fontWeight={isToday ? 700 : 500}
        fill={isToday ? "var(--text)" : "var(--text-3)"}
      >
        {label}
      </text>
    );
  }

  return (
    <div style={{ width: "100%" }} role="img" aria-label={aria["aria-label"]}>
      <ResponsiveContainer width="100%" height={height}>
        <BarChart data={data} margin={{ top: 24, right: 8, bottom: 0, left: 0 }}>
          <CartesianGrid vertical={false} stroke="var(--grid)" />
          <YAxis width={44} tickCount={3} ticks={[0, top / 2, top]} domain={[0, top]} tickFormatter={yFormat ?? format.compactAxis} axisLine={false} tickLine={false} tick={{ fontSize: 11, fill: "var(--text-3)" }} />
          <XAxis dataKey="label" axisLine={false} tickLine={false} tick={renderTick} interval={0} />
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
          <Bar dataKey="value" shape={renderBar} isAnimationActive={!reduced} animationDuration={900} />
        </BarChart>
      </ResponsiveContainer>
      {legend && (
        <p className="type-body-s text-center mt-1" style={{ color: "var(--text-3)" }}>
          {legend}
        </p>
      )}
    </div>
  );
}

function useIsDarkTheme(): boolean {
  const preference = useTheme((s) => s.preference);
  const prefersLight = useMediaQuery("(prefers-color-scheme: light)");
  if (preference === "system") return !prefersLight;
  return preference === "dark";
}
