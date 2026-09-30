/**
 * The points of a tiny trend line scaled into a `width` × `height` box with
 * `pad` px of breathing room — the y axis is inverted (bigger value = higher
 * on screen) and a flat series sits on the middle line instead of dividing by
 * zero. Pure, so it's unit-tested (`trendSpark.test.ts`).
 */
export function sparkPoints(values: number[], width: number, height: number, pad = 2): [number, number][] {
  if (values.length === 0) return [];
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min;
  const innerW = width - pad * 2;
  const innerH = height - pad * 2;
  return values.map((v, i) => [
    pad + (values.length === 1 ? innerW / 2 : (i / (values.length - 1)) * innerW),
    span === 0 ? height / 2 : pad + (1 - (v - min) / span) * innerH,
  ]);
}

export interface TrendSparkProps {
  values: number[];
  color: string;
  width?: number;
  height?: number;
  /** Read instead of the drawing — omit for a purely decorative line next to its own number. */
  "aria-label"?: string;
}

/**
 * A tiny, axis-less trend line for a tile (W1.7's weight tile): one stroke in
 * the metric colour, no markers, no animation. Dependency-free SVG — a chart
 * library for a 70 × 28 px line would cost the dashboard more than the line
 * is worth.
 */
export function TrendSpark({ values, color, width = 72, height = 28, ...aria }: TrendSparkProps) {
  const pts = sparkPoints(values, width, height);
  if (pts.length < 2) return null;
  const label = aria["aria-label"];
  return (
    <svg
      width={width}
      height={height}
      viewBox={`0 0 ${width} ${height}`}
      role={label ? "img" : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      data-testid="trend-spark"
    >
      <polyline
        points={pts.map(([x, y]) => `${x.toFixed(1)},${y.toFixed(1)}`).join(" ")}
        fill="none"
        stroke={color}
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
