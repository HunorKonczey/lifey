import { formatDuration } from "./cardioFormat";
import type { PaceBar } from "./paceBarGeometry";
import type { CardioSplitResponse } from "./types";

/**
 * Converts `session.splits` into `PaceBarChart` bars — the same threshold
 * mobile's `cardio_summary_screen.dart` uses for `PaceBar.partial`
 * (`distanceMeters < 999`, not `< 1000`, to absorb rounding). Sorted by
 * `splitIndex`, same as `CardioSplitsTable`, so both views of the same
 * `session.splits` agree on order.
 */
export function buildPaceBars(splits: CardioSplitResponse[]): PaceBar[] {
  return [...splits]
    .sort((a, b) => a.splitIndex - b.splitIndex)
    .map((split) => ({
      durationSeconds: split.durationSeconds,
      label: formatDuration(split.durationSeconds),
      partial: (split.distanceMeters ?? 0) < 999,
    }));
}
