import { buildRouteGeometry } from "../routeGeometry";
import type { CardioWaypointResponse } from "../types";

const WIDTH = 400;
const HEIGHT = 220;
const MARGIN = 20;

interface RouteSvgProps {
  polyline: string;
  waypoints?: CardioWaypointResponse[];
}

/**
 * Draws a session's GPS route from its stored `route_polyline` — the web
 * counterpart of the mobile `RoutePainter` (docs/cardio/54 §6.1, 58 WB8):
 * same visual language (rounded surface-container backdrop, primary-colored
 * line, dashed bridge across a GPS gap, start/end rings), same "saved SVG
 * drawing, not a map" decision (58 D-W.3), just SVG markup instead of a
 * `CustomPainter`. Numbered waypoint markers (docs/cardio/60 C8.4, M41) draw
 * on top when the session carried any.
 */
export function RouteSvg({ polyline, waypoints = [] }: RouteSvgProps) {
  const geometry = buildRouteGeometry(
    polyline,
    waypoints.map((w) => ({ latitude: w.latitude, longitude: w.longitude })),
    WIDTH,
    HEIGHT,
    MARGIN,
  );
  if (!geometry) return null;

  const { segments, start, end, waypoints: projectedWaypoints } = geometry;

  return (
    <svg
      viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
      className="w-full h-auto rounded-[var(--r-card)]"
      role="img"
      aria-hidden="true"
    >
      <rect width={WIDTH} height={HEIGHT} fill="var(--surface-container)" rx={12} />

      {segments.length > 1 &&
        segments.slice(1).map((segment, i) => {
          const prevEnd = segments[i][segments[i].length - 1];
          const currStart = segment[0];
          if (!prevEnd || !currStart) return null;
          return (
            <line
              key={`bridge-${i}`}
              x1={prevEnd.x}
              y1={prevEnd.y}
              x2={currStart.x}
              y2={currStart.y}
              stroke="var(--primary)"
              strokeOpacity={0.55}
              strokeWidth={2}
              strokeDasharray="5 4"
              strokeLinecap="round"
            />
          );
        })}

      {segments.map(
        (segment, i) =>
          segment.length >= 2 && (
            <polyline
              key={`segment-${i}`}
              points={segment.map((p) => `${p.x},${p.y}`).join(" ")}
              fill="none"
              stroke="var(--primary)"
              strokeWidth={3.5}
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          ),
      )}

      {projectedWaypoints.map((point, i) => (
        <g key={`waypoint-${i}`}>
          <circle cx={point.x} cy={point.y} r={3.5} fill="var(--tertiary)" stroke="var(--surface-container)" strokeWidth={1.5} />
          <text x={point.x + 5} y={point.y - 5} fontSize={9} fontWeight={800} fill="var(--on-surface)">
            {waypoints[i]?.waypointIndex != null ? waypoints[i].waypointIndex + 1 : i + 1}
          </text>
        </g>
      ))}

      <circle cx={start.x} cy={start.y} r={5} fill="var(--surface-container)" stroke="var(--primary)" strokeWidth={2} />
      <circle cx={end.x} cy={end.y} r={5} fill="var(--secondary)" />
    </svg>
  );
}
