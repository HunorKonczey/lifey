import { create } from "zustand";

type WorkoutsTab = "sessions" | "templates" | "exercises";

interface UiState {
  drawerOpen: boolean;
  openDrawer: () => void;
  closeDrawer: () => void;
  toggleDrawer: () => void;

  workoutsTab: WorkoutsTab;
  setWorkoutsTab: (tab: WorkoutsTab) => void;
}

export const useUiStore = create<UiState>((set) => ({
  drawerOpen: false,
  openDrawer: () => set({ drawerOpen: true }),
  closeDrawer: () => set({ drawerOpen: false }),
  toggleDrawer: () => set((s) => ({ drawerOpen: !s.drawerOpen })),

  workoutsTab: "sessions",
  setWorkoutsTab: (tab) => set({ workoutsTab: tab }),
}));
