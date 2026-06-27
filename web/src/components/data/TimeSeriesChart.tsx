"use client";

import {
  ResponsiveContainer, AreaChart, Area, XAxis, YAxis,
  Tooltip, ReferenceLine, CartesianGrid,
} from "recharts";

export interface SeriesPoint {
  date: string; // label
  value: number;
}

interface TimeSeriesChartProps {
  data: SeriesPoint[];
  color: string;
  goalLine?: number;
  goalLabel?: string;
  height?: number;
  unit?: string;
}

export function TimeSeriesChart({
  data, color, goalLine, goalLabel, height = 240, unit = "",
}: TimeSeriesChartProps) {
  const gradientId = `grad-${color.replace(/[^a-z0-9]/gi, "")}`;

  return (
    <ResponsiveContainer width="100%" height={height}>
      <AreaChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: -16 }}>
        <defs>
          <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity={0.35} />
            <stop offset="100%" stopColor={color} stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="var(--outline)" vertical={false} />
        <XAxis
          dataKey="date"
          tick={{ fill: "var(--muted)", fontSize: 11 }}
          axisLine={{ stroke: "var(--outline)" }}
          tickLine={false}
          interval="preserveStartEnd"
          minTickGap={28}
        />
        <YAxis
          tick={{ fill: "var(--muted)", fontSize: 11 }}
          axisLine={false}
          tickLine={false}
          width={44}
          domain={["auto", "auto"]}
        />
        <Tooltip
          contentStyle={{
            background: "var(--surface-high)",
            border: "1px solid var(--outline)",
            borderRadius: "var(--r-md)",
            fontSize: 12,
          }}
          labelStyle={{ color: "var(--on-surface-variant)" }}
          formatter={(v) => [`${v}${unit}`, ""] as [string, string]}
        />
        {goalLine != null && (
          <ReferenceLine
            y={goalLine}
            stroke="var(--primary)"
            strokeDasharray="5 5"
            label={{
              value: goalLabel ?? `Goal ${goalLine}${unit}`,
              fill: "var(--primary)",
              fontSize: 11,
              position: "insideTopRight",
            }}
          />
        )}
        <Area
          type="monotone"
          dataKey="value"
          stroke={color}
          strokeWidth={2.5}
          fill={`url(#${gradientId})`}
          dot={{ r: 2.5, fill: color }}
          activeDot={{ r: 4 }}
        />
      </AreaChart>
    </ResponsiveContainer>
  );
}
