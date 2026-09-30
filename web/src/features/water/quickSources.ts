import type { WaterEntryResponse, WaterSourceResponse } from "./types";

/** One quick-add button on the dashboard's water tile. */
export interface QuickSource {
  /** `null` for a built-in default that isn't a saved source. */
  sourceId: number | null;
  volumeLiters: number;
}

/** What the tile offers when the user has used fewer than two sources lately. */
export const DEFAULT_QUICK_VOLUMES = [0.25, 0.5] as const;

const WINDOW_DAYS = 30;
const DAY_MS = 86_400_000;

/**
 * The two quick-add buttons of the water tile (W1.5): the user's two most
 * used saved sources over the last 30 days — most entries first, the more
 * recently used breaking a tie. When fewer than two sources qualify, the
 * gap is filled with the 0.25 / 0.5 L defaults (skipping a volume already
 * offered), so the tile always has two sensible buttons.
 */
export function rankQuickSources(
  entries: WaterEntryResponse[],
  sources: WaterSourceResponse[],
  now: Date,
  limit = 2,
): QuickSource[] {
  const since = now.getTime() - WINDOW_DAYS * DAY_MS;
  const usage = new Map<number, { count: number; last: number }>();

  for (const e of entries) {
    if (e.sourceId == null) continue;
    const at = new Date(e.consumedAt).getTime();
    if (at < since || at > now.getTime()) continue;
    const u = usage.get(e.sourceId) ?? { count: 0, last: 0 };
    usage.set(e.sourceId, { count: u.count + 1, last: Math.max(u.last, at) });
  }

  const ranked: QuickSource[] = sources
    .filter((s) => usage.has(s.id))
    .sort((a, b) => {
      const ua = usage.get(a.id)!;
      const ub = usage.get(b.id)!;
      return ub.count - ua.count || ub.last - ua.last || a.id - b.id;
    })
    .slice(0, limit)
    .map((s) => ({ sourceId: s.id, volumeLiters: s.volumeLiters }));

  for (const volume of DEFAULT_QUICK_VOLUMES) {
    if (ranked.length >= limit) break;
    if (!ranked.some((r) => r.volumeLiters === volume)) ranked.push({ sourceId: null, volumeLiters: volume });
  }
  return ranked;
}
