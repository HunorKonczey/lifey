import { create } from "zustand";

interface DateState {
  date: Date;
  setDate: (date: Date) => void;
  dateStr: () => string;
}

export const useDateStore = create<DateState>((set, get) => ({
  date: new Date(),
  setDate: (date) => set({ date }),
  dateStr: () => {
    const d = get().date;
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  },
}));
