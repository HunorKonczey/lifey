"use client";

import { ResponsiveContainer, LineChart, Line } from "recharts";

export interface SparklinePoint {
  date: string;
  value: number;
}

interface SparklineProps {
  data: SparklinePoint[];
  color?: string;
  height?: number;
}

/** Compact, axis-less trend line for dashboard cards (e.g. client weight
 *  trend — docs/personal_trainer/06-design.md §3.2). Not interactive. */
export function Sparkline({ data, color = "var(--tertiary)", height = 32 }: SparklineProps) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <LineChart data={data} margin={{ top: 2, right: 2, bottom: 2, left: 2 }}>
        <Line
          type="monotone"
          dataKey="value"
          stroke={color}
          strokeWidth={2}
          dot={false}
          isAnimationActive={false}
        />
      </LineChart>
    </ResponsiveContainer>
  );
}
