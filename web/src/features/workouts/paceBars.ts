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
export function buildPaceBars(splits: CardioSplitResponse[], locale = "en"): PaceBar[] {
  return [...splits]
    .sort((a, b) => a.splitIndex - b.splitIndex)
    .map((split) => {
      const partial = (split.distanceMeters ?? 0) < 999;
      return {
        durationSeconds: split.durationSeconds,
        label: formatDuration(split.durationSeconds),
        partial,
        distanceMeters: split.distanceMeters ?? undefined,
        // "0,2" — the tail's kilometres, one decimal, in the UI language
        partialLabel: partial && split.distanceMeters != null
          ? new Intl.NumberFormat(locale, { maximumFractionDigits: 1 }).format(split.distanceMeters / 1000)
          : undefined,
      };
    });
}
