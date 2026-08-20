import type { WorkoutSessionResponse } from "./types";

export type BestEffortDistance = "1k" | "5k" | "10k";

const FIELD_BY_DISTANCE: Record<BestEffortDistance, "best1kSeconds" | "best5kSeconds" | "best10kSeconds"> = {
  "1k": "best1kSeconds",
  "5k": "best5kSeconds",
  "10k": "best10kSeconds",
};

/**
 * Which best-effort distances `target` set a new record for, computed from
 * `allSessions` — the web port of the mobile `CardioPrBaseline`/
 * `detectCardioPrs` (`domain/cardio_personal_record.dart`), narrowed to the
 * `fastest1k`/`fastest5k`/`fastest10k` record types only (docs/cardio/60 §8
 * C6w.4). Cardio PRs have no server-side representation (they're computed,
 * never stored — same as on mobile), so this recomputes the baseline from
 * the session list the web already fetches for every other session view,
 * rather than needing a new backend endpoint.
 *
 * Mirrors the mobile engine's rules exactly:
 * - **RUNNING only** (`CardioPrType.fastest1k.appliesTo`) — a walk or hike's
 *   best effort neither sets nor breaks this record, even though the
 *   `BestEffortsCard` happily displays one for the whole `DISTANCE` family.
 * - **Strictly better** than every earlier baseline value — matching the
 *   existing best is not a new record.
 * - **A type never fires without a baseline value to beat** — the first run
 *   of a distance sets the bar, it doesn't break one.
 * - The baseline only looks at sessions that **finished strictly before**
 *   `target` — a session can't be beaten by one that came after it.
 */
export function detectBestEffortRecords(
  allSessions: WorkoutSessionResponse[],
  target: WorkoutSessionResponse,
): Set<BestEffortDistance> {
  const records = new Set<BestEffortDistance>();
  if (target.activityType !== "RUNNING" || target.finishedAt == null || target.cardio == null) return records;

  const priorRuns = allSessions.filter(
    (s) =>
      s.id !== target.id &&
      s.activityType === "RUNNING" &&
      s.finishedAt != null &&
      s.finishedAt < target.finishedAt! &&
      s.cardio != null,
  );

  for (const distance of Object.keys(FIELD_BY_DISTANCE) as BestEffortDistance[]) {
    const field = FIELD_BY_DISTANCE[distance];
    const value = target.cardio[field];
    if (value == null) continue;

    let baseline: number | null = null;
    for (const run of priorRuns) {
      const priorValue = run.cardio![field];
      if (priorValue == null) continue;
      if (baseline == null || priorValue < baseline) baseline = priorValue;
    }
    if (baseline != null && value < baseline) records.add(distance);
  }

  return records;
}
