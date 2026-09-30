import { describe, expect, it } from "vitest";
import { rankQuickSources } from "./quickSources";
import type { WaterEntryResponse, WaterSourceResponse } from "./types";

const now = new Date(2026, 8, 30, 15, 0);
const daysAgo = (d: number, hour = 12) => new Date(2026, 8, 30 - d, hour, 0).toISOString();

const glass: WaterSourceResponse = { id: 1, name: "Glass", volumeLiters: 0.25 };
const bottle: WaterSourceResponse = { id: 2, name: "Bottle", volumeLiters: 0.75 };
const mug: WaterSourceResponse = { id: 3, name: "Mug", volumeLiters: 0.3 };

function entry(id: number, sourceId: number | null, consumedAt: string, volume = 0.25): WaterEntryResponse {
  return { id, sourceId, sourceName: null, consumedAt, volumeLiters: volume };
}

describe("rankQuickSources", () => {
  it("ranks saved sources by how often they were used in the last 30 days", () => {
    const entries = [entry(1, 2, daysAgo(1)), entry(2, 2, daysAgo(2)), entry(3, 2, daysAgo(3)), entry(4, 1, daysAgo(1)), entry(5, 3, daysAgo(1)), entry(6, 3, daysAgo(2))];
    expect(rankQuickSources(entries, [glass, bottle, mug], now)).toEqual([
      { sourceId: 2, volumeLiters: 0.75 },
      { sourceId: 3, volumeLiters: 0.3 },
    ]);
  });

  it("breaks a tie by the more recent use, then by id", () => {
    const entries = [entry(1, 1, daysAgo(5)), entry(2, 3, daysAgo(1))];
    expect(rankQuickSources(entries, [glass, mug], now).map((s) => s.sourceId)).toEqual([3, 1]);
    const sameDay = [entry(1, 1, daysAgo(2)), entry(2, 3, daysAgo(2))];
    expect(rankQuickSources(sameDay, [glass, mug], now).map((s) => s.sourceId)).toEqual([1, 3]);
  });

  it("ignores entries older than 30 days, future ones, and entries without a source", () => {
    const entries = [entry(1, 2, daysAgo(31)), entry(2, 2, daysAgo(45)), entry(3, null, daysAgo(1)), entry(4, 1, new Date(2026, 8, 30, 18, 0).toISOString())];
    // nothing qualifies → both defaults
    expect(rankQuickSources(entries, [glass, bottle], now)).toEqual([
      { sourceId: null, volumeLiters: 0.25 },
      { sourceId: null, volumeLiters: 0.5 },
    ]);
  });

  it("counts an entry exactly 30 days old", () => {
    expect(rankQuickSources([entry(1, 2, daysAgo(30, 15))], [bottle], now)[0]).toEqual({ sourceId: 2, volumeLiters: 0.75 });
  });

  it("with one used source, fills the second slot from the defaults", () => {
    const out = rankQuickSources([entry(1, 2, daysAgo(1))], [bottle], now);
    expect(out).toEqual([
      { sourceId: 2, volumeLiters: 0.75 },
      { sourceId: null, volumeLiters: 0.25 },
    ]);
  });

  it("doesn't offer a default volume a used source already covers", () => {
    const out = rankQuickSources([entry(1, 1, daysAgo(1))], [glass], now); // glass is 0.25 L
    expect(out).toEqual([
      { sourceId: 1, volumeLiters: 0.25 },
      { sourceId: null, volumeLiters: 0.5 },
    ]);
  });

  it("ignores usage of a source that no longer exists", () => {
    expect(rankQuickSources([entry(1, 99, daysAgo(1))], [glass], now).every((s) => s.sourceId === null)).toBe(true);
  });

  it("with no data at all: the 0.25 / 0.5 L defaults", () => {
    expect(rankQuickSources([], [], now)).toEqual([
      { sourceId: null, volumeLiters: 0.25 },
      { sourceId: null, volumeLiters: 0.5 },
    ]);
  });
});
