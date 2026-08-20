import { describe, it, expect } from "vitest";
import { decodePolyline3, decodeRouteSegments, buildRouteGeometry, flattenAltitudes } from "./routeGeometry";

describe("decodePolyline3", () => {
  it("decodes a single point at the origin (all-zero deltas encode to '?')", () => {
    expect(decodePolyline3("???")).toEqual([[0, 0, 0]]);
  });

  it("decodes two points via delta-encoded, zigzag-signed values", () => {
    // Point 2 is +0.00001 lat (1 unit at 1e5 precision) from point 1 — a
    // positive delta of 1 encodes to a single char 'A' per the zigzag+base64
    // scheme (`(1 << 1) + 63 = 65 = 'A'`), with lng/alt deltas of 0 ('?').
    const points = decodePolyline3("???A??");
    expect(points).toHaveLength(2);
    expect(points[0]).toEqual([0, 0, 0]);
    expect(points[1][0]).toBeCloseTo(0.00001, 5);
    expect(points[1][1]).toBeCloseTo(0, 5);
    expect(points[1][2]).toBeCloseTo(0, 5);
  });

  it("decodes a negative delta", () => {
    // -1 zigzags: `~(-1 << 1) = ~(-2) = 1`, `1 + 63 = 64 = '@'`.
    const points = decodePolyline3("???@??");
    expect(points[1][0]).toBeCloseTo(-0.00001, 5);
  });
});

describe("decodeRouteSegments", () => {
  it("returns an empty array for an empty polyline (no route recorded)", () => {
    expect(decodeRouteSegments("")).toEqual([]);
  });

  it("splits on ';' into independent segments (a GPS gap between them)", () => {
    const segments = decodeRouteSegments("???;???");
    expect(segments).toHaveLength(2);
    expect(segments[0]).toEqual([[0, 0, 0]]);
    expect(segments[1]).toEqual([[0, 0, 0]]);
  });

  it("ignores an empty trailing segment (no stray gap at the end)", () => {
    expect(decodeRouteSegments("???;")).toHaveLength(1);
  });
});

describe("buildRouteGeometry", () => {
  it("returns null for an empty polyline", () => {
    expect(buildRouteGeometry("", [], 400, 220, 20)).toBeNull();
  });

  it("projects a single segment into the pixel box, respecting the margin", () => {
    const geometry = buildRouteGeometry("???A??", [], 400, 220, 20);
    expect(geometry).not.toBeNull();
    expect(geometry!.segments).toHaveLength(1);
    expect(geometry!.segments[0]).toHaveLength(2);
    for (const segment of geometry!.segments) {
      for (const point of segment) {
        expect(point.x).toBeGreaterThanOrEqual(20);
        expect(point.x).toBeLessThanOrEqual(380);
        expect(point.y).toBeGreaterThanOrEqual(20);
        expect(point.y).toBeLessThanOrEqual(200);
      }
    }
  });

  it("does not crash on a degenerate single-point route (zero data width/height)", () => {
    const geometry = buildRouteGeometry("???", [], 400, 220, 20);
    expect(geometry).not.toBeNull();
    expect(geometry!.start).toEqual(geometry!.end);
    expect(Number.isFinite(geometry!.start.x)).toBe(true);
    expect(Number.isFinite(geometry!.start.y)).toBe(true);
  });

  it("projects waypoints onto the same bounding box as the route", () => {
    const geometry = buildRouteGeometry("???A??", [{ latitude: 0, longitude: 0 }], 400, 220, 20);
    expect(geometry!.waypoints).toHaveLength(1);
    // The waypoint sits exactly on the route's start point (same lat/lng).
    expect(geometry!.waypoints[0]).toEqual(geometry!.start);
  });

  it("start and end mark the first and last points across all segments", () => {
    const geometry = buildRouteGeometry("???A??;???A??", [], 400, 220, 20);
    expect(geometry!.segments).toHaveLength(2);
    expect(geometry!.start).toEqual(geometry!.segments[0][0]);
    expect(geometry!.end).toEqual(geometry!.segments[1][1]);
  });

  it("stays readable with 50 waypoints (docs/cardio/60 §8 C8w.2, mirrors the mobile C8.4 test case)", () => {
    const polyline = "???" + "A??".repeat(49); // 50 chained points
    const waypointCoords = Array.from({ length: 50 }, (_, i) => ({ latitude: i * 0.00001, longitude: 0 }));
    const geometry = buildRouteGeometry(polyline, waypointCoords, 400, 220, 20);
    expect(geometry).not.toBeNull();
    expect(geometry!.segments[0]).toHaveLength(50);
    expect(geometry!.waypoints).toHaveLength(50);
    for (const point of geometry!.waypoints) {
      expect(Number.isFinite(point.x)).toBe(true);
      expect(Number.isFinite(point.y)).toBe(true);
    }
  });
});

describe("flattenAltitudes", () => {
  it("returns an empty array for an empty polyline", () => {
    expect(flattenAltitudes("")).toEqual([]);
  });

  it("flattens a single segment's altitude channel in point order", () => {
    // One segment, two points: (0,0,0) then a +2 raw-unit altitude delta
    // ('C' = zigzag(2) → chunk 4 → char(4+63)) = +0.2 m at the 1e1 altitude precision.
    expect(flattenAltitudes("?????C")).toEqual([0, 0.2]);
  });

  it("concatenates altitudes across segments, ignoring the gap boundary", () => {
    expect(flattenAltitudes("???;???")).toEqual([0, 0]);
  });
});
