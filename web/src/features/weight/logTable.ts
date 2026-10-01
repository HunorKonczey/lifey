import type { WeightResponse } from "./types";

export interface WeightLogRow {
  entry: WeightResponse;
  /** Change against the previous entry in time (rounded to 0,1 kg); null for the very first weigh-in. */
  delta: number | null;
}

/**
 * The rows of the weight log table (W4.3), newest first: every entry with its change against the one before it in
 * time. Entries are ordered by date, then by id (recording order) for the same day; the change is rounded to the
 * one decimal the scale shows, so 69,8 → 69,6 is −0,2 and never −0,19999.
 */
export function weightLogRows(weights: readonly WeightResponse[]): WeightLogRow[] {
  const asc = [...weights].sort((a, b) => a.date.localeCompare(b.date) || a.id - b.id);
  const rows = asc.map((entry, i) => ({
    entry,
    delta: i === 0 ? null : Math.round((entry.weight - asc[i - 1].weight) * 10) / 10,
  }));
  return rows.reverse();
}

/** "Péntek, szept. 26." / "Friday, Sep 26" — weekday spelled out, first letter capital (Hungarian weekdays are lower case). */
export function logDateLabel(date: Date, locale: string, shortDate: (d: Date) => string): string {
  const weekday = new Intl.DateTimeFormat(locale, { weekday: "long" }).format(date);
  return `${weekday.charAt(0).toLocaleUpperCase(locale)}${weekday.slice(1)}, ${shortDate(date)}`;
}
