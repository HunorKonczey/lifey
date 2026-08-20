import { formatPace } from "./cardioFormat";
import type { BestEffortDistance } from "./cardioBestEffortRecords";
import type { CardioDetailsResponse } from "./types";

export interface BestEffortRow {
  labelKey: string;
  seconds: number;
  pace: string | null;
  isRecord: boolean;
}

const DISTANCES: { key: "best1kSeconds" | "best5kSeconds" | "best10kSeconds"; labelKey: string; meters: number; distance: BestEffortDistance }[] = [
  { key: "best1kSeconds", labelKey: "cardioBestEffort1kLabel", meters: 1000, distance: "1k" },
  { key: "best5kSeconds", labelKey: "cardioBestEffort5kLabel", meters: 5000, distance: "5k" },
  { key: "best10kSeconds", labelKey: "cardioBestEffort10kLabel", meters: 10000, distance: "10k" },
];

/**
 * Builds the `BestEffortsCard` rows from a session's cardio details — a pure
 * function so the "a distance the session never reached doesn't appear at
 * all" rule (docs/cardio/60 M34) is unit-testable without a component-testing
 * setup (this project's `vitest.config.ts` only runs `.test.ts`).
 *
 * `records` (docs/cardio/60 §8 C6w.4) marks which distances this session set
 * a new personal best for — omit it (or pass an empty set) to render every
 * row unmarked, e.g. for a WALKING/HIKING session, which can have a best
 * effort but never a record (`detectBestEffortRecords` is RUNNING-only).
 */
export function buildBestEffortRows(
  cardio: CardioDetailsResponse,
  records: ReadonlySet<BestEffortDistance> = new Set(),
): BestEffortRow[] {
  const rows: BestEffortRow[] = [];
  for (const { key, labelKey, meters, distance } of DISTANCES) {
    const seconds = cardio[key];
    if (seconds == null) continue;
    rows.push({ labelKey, seconds, pace: formatPace(meters, seconds), isRecord: records.has(distance) });
  }
  return rows;
}
