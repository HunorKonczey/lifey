import { addDays, format, getDate, getMonth } from "date-fns";
import type { LifeyFormat } from "@/lib/format/lifeyFormat";
import type { StatsPeriod } from "./period";
import type { Slot } from "./periodStats";

/**
 * The X axis of every statistics chart (W5.5/W5.6), one label per column:
 *
 * - **week** — the weekday ("H K Sze Cs P Szo V"), today as "Ma";
 * - **month** — the 1st as "szept. 1.", then every fifth day as a bare number; everything else stays empty so 30
 *   labels never crowd a 358 px card;
 * - **year** — a month name over the first week of each month.
 *
 * `key` is unique per column (the ISO date) — recharts keys its category axis by it, and the printed `axisLabel`
 * may be empty or repeat.
 */
export interface AxisColumn {
  key: string;
  axisLabel: string;
  isToday: boolean;
}

export function axisColumns(period: StatsPeriod, slots: Slot[], fmt: LifeyFormat, todayLabel: string): AxisColumn[] {
  return slots.map((slot, i) => {
    const key = format(slot.start, "yyyy-MM-dd");
    const isToday = period !== "year" && slot.isCurrent;
    if (period === "week") return { key, axisLabel: isToday ? todayLabel : fmt.weekdayShort(slot.start), isToday };
    if (period === "month") {
      const day = getDate(slot.start);
      if (isToday) return { key, axisLabel: todayLabel, isToday };
      if (day === 1) return { key, axisLabel: fmt.shortDate(slot.start), isToday };
      return { key, axisLabel: day % 5 === 0 && day <= 30 ? String(day) : "", isToday };
    }
    // Year: name a month over its first column. A column belongs to the month holding its middle day, so a week
    // straddling two months is named once and "jan." always sits over the first column.
    const label = monthStartsHere(slot, slots[i - 1]) ? fmt.monthShort(middleDay(slot)) : "";
    return { key, axisLabel: label, isToday: false };
  });
}

function middleDay(slot: Slot): Date {
  return addDays(slot.start, Math.floor((slot.end.getTime() - slot.start.getTime()) / 86_400_000 / 2));
}

function monthStartsHere(slot: Slot, previous: Slot | undefined): boolean {
  return previous == null || getMonth(middleDay(slot)) !== getMonth(middleDay(previous));
}
