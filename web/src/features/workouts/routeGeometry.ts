/**
 * Decodes a session's `cardio.routePolyline` and projects it into pixel
 * space for `RouteSvg` — the web port of the mobile `route_encoder.dart` /
 * `polyline_codec.dart` decode side plus `RoutePainter`'s Web-Mercator
 * projection and bounding-box fit (docs/cardio/58 D-W.3: a saját rajz, nem
 * térkép — no map library, no tile license).
 *
 * The web never *encodes* a route (D-W.1/D-W.2: cardio can't be started or
 * edited from here), so only the decode direction exists on this side.
 */

const COORDINATE_PRECISION = 1e5;
const ALTITUDE_PRECISION = 1e1;

/** [lat, lng, altitudeMeters] per point. */
export type RoutePoint = [number, number, number];

function decodeValue(encoded: string, index: number): { value: number; nextIndex: number } {
  let result = 0;
  let shift = 0;
  let chunk: number;
  let i = index;
  do {
    chunk = encoded.charCodeAt(i) - 63;
    i++;
    result |= (chunk & 0x1f) << shift;
    shift += 5;
  } while (chunk >= 0x20);
  const value = (result & 1) !== 0 ? ~(result >> 1) : result >> 1;
  return { value, nextIndex: i };
}

/** The plain three-channel (lat, lng, altitude) decode — mirrors `decodePolyline3`. */
export function decodePolyline3(encoded: string): RoutePoint[] {
  const points: RoutePoint[] = [];
  let index = 0;
  let lat = 0;
  let lng = 0;
  let alt = 0;
  while (index < encoded.length) {
    const decodedLat = decodeValue(encoded, index);
    lat += decodedLat.value;
    index = decodedLat.nextIndex;
    const decodedLng = decodeValue(encoded, index);
    lng += decodedLng.value;
    index = decodedLng.nextIndex;
    const decodedAlt = decodeValue(encoded, index);
    alt += decodedAlt.value;
    index = decodedAlt.nextIndex;
    points.push([lat / COORDINATE_PRECISION, lng / COORDINATE_PRECISION, alt / ALTITUDE_PRECISION]);
  }
  return points;
}

/**
 * Splits on `;` (segment boundary = a GPS gap, mirrors `decodeRouteSegments`).
 * An empty polyline (no route recorded) decodes to an empty array, not an
 * array containing one empty segment.
 */
export function decodeRouteSegments(polyline: string): RoutePoint[][] {
  if (polyline.length === 0) return [];
  return polyline
    .split(";")
    .filter((segment) => segment.length > 0)
    .map(decodePolyline3);
}

/**
 * Flattens a polyline's altitude channel into a single point-index-ordered
 * array — the web port of the mobile "C4a.6-era approximation" fallback
 * (`cardio_summary_screen.dart`'s `_routeSections`, docs/cardio/60 §8
 * C8w.1): a synthetic per-point index stands in for a real X axis, because
 * the polyline carries no timestamps and the profile's job here is only
 * showing the route's *shape*. Segment boundaries (GPS gaps) don't interrupt
 * the index — mobile's fallback doesn't shade gaps either, unlike the real
 * C8.3 profile.
 */
export function flattenAltitudes(polyline: string): number[] {
  return decodeRouteSegments(polyline)
    .flat()
    .map(([, , alt]) => alt);
}

export interface ProjectedPoint {
  x: number;
  y: number;
}

function mercator(lat: number, lng: number): ProjectedPoint {
  const latRad = (lat * Math.PI) / 180;
  return { x: lng, y: Math.log(Math.tan(Math.PI / 4 + latRad / 2)) };
}

/** Fits a set of Mercator-projected points into `width`x`height`, preserving aspect ratio, centered. */
function fit(points: ProjectedPoint[], width: number, height: number, margin: number) {
  let minX = points[0].x, maxX = points[0].x;
  let minY = points[0].y, maxY = points[0].y;
  for (const p of points) {
    if (p.x < minX) minX = p.x;
    if (p.x > maxX) maxX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.y > maxY) maxY = p.y;
  }
  const dataWidth = maxX - minX;
  const dataHeight = maxY - minY;
  const availableWidth = Math.max(1, width - margin * 2);
  const availableHeight = Math.max(1, height - margin * 2);

  let scale: number;
  if (dataWidth === 0 && dataHeight === 0) {
    scale = 1;
  } else if (dataWidth === 0) {
    scale = availableHeight / dataHeight;
  } else if (dataHeight === 0) {
    scale = availableWidth / dataWidth;
  } else {
    scale = Math.min(availableWidth / dataWidth, availableHeight / dataHeight);
  }

  const offsetX = (width - dataWidth * scale) / 2;
  const offsetY = (height - dataHeight * scale) / 2;

  // Mercator y increases northward; SVG y increases downward — flip.
  return (p: ProjectedPoint): ProjectedPoint => ({
    x: offsetX + (p.x - minX) * scale,
    y: offsetY + (maxY - p.y) * scale,
  });
}

export interface RouteGeometry {
  /** Each segment's points, already projected into `width`x`height` pixel space. */
  segments: ProjectedPoint[][];
  start: ProjectedPoint;
  end: ProjectedPoint;
  /** Same order as the `waypointCoords` input. */
  waypoints: ProjectedPoint[];
}

/**
 * Decodes `polyline` and projects it (plus any waypoint coordinates, on the
 * same bounding box so both line up) into `width`x`height` pixel space.
 * `null` when the polyline is empty — the caller renders nothing rather than
 * an empty frame.
 */
export function buildRouteGeometry(
  polyline: string,
  waypointCoords: { latitude: number; longitude: number }[],
  width: number,
  height: number,
  margin: number,
): RouteGeometry | null {
  const segments = decodeRouteSegments(polyline);
  const allPoints = segments.flat();
  if (allPoints.length === 0) return null;

  const projectedSegments = segments.map((segment) => segment.map(([lat, lng]) => mercator(lat, lng)));
  const project = fit(projectedSegments.flat(), width, height, margin);

  return {
    segments: projectedSegments.map((segment) => segment.map(project)),
    start: project(projectedSegments[0][0]),
    end: project(projectedSegments[projectedSegments.length - 1][projectedSegments[projectedSegments.length - 1].length - 1]),
    waypoints: waypointCoords.map(({ latitude, longitude }) => project(mercator(latitude, longitude))),
  };
}
