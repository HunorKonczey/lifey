import { create } from "zustand";
import { isSameDay } from "date-fns";
import { isFuture } from "@/components/ds/date/monthGrid";

interface DateState {
  date: Date;
  /** True once the user has explicitly picked a day other than today (via
   * the prev/next arrows) — prevents `syncToday` from yanking them back to
   * today while they're deliberately looking at another day. */
  isPinned: boolean;
  setDate: (date: Date) => void;
  /** Rolls `date` forward to the real current day if the user hasn't
   * pinned it to a specific day — call this when the tab regains focus so
   * a browser tab left open overnight doesn't keep filtering "today"'s
   * data against yesterday's date. See AppLayout. */
  syncToday: () => void;
  dateStr: () => string;
}

export const useDateStore = create<DateState>((set, get) => ({
  date: new Date(),
  isPinned: false,
  setDate: (date) => {
    // The old top bar's `addDays` had no ceiling — the "next day" arrow
    // could walk into next week (D-W0.21). Clamp instead of ignoring the
    // call, so a click that lands exactly on today from the past still works.
    const today = new Date();
    const clamped = isFuture(date, today) ? today : date;
    set({ date: clamped, isPinned: !isSameDay(clamped, today) });
  },
  syncToday: () => {
    if (!get().isPinned) set({ date: new Date() });
  },
  dateStr: () => {
    const d = get().date;
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  },
}));
