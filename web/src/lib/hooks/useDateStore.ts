import { create } from "zustand";
import { isSameDay } from "date-fns";

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
  setDate: (date) => set({ date, isPinned: !isSameDay(date, new Date()) }),
  syncToday: () => {
    if (!get().isPinned) set({ date: new Date() });
  },
  dateStr: () => {
    const d = get().date;
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  },
}));
