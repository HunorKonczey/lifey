import { create } from "zustand";

type NutritionTab = "meals" | "foods" | "recipes";
type WorkoutsTab = "sessions" | "templates" | "exercises";

interface UiState {
  drawerOpen: boolean;
  openDrawer: () => void;
  closeDrawer: () => void;
  toggleDrawer: () => void;

  nutritionTab: NutritionTab;
  setNutritionTab: (tab: NutritionTab) => void;

  workoutsTab: WorkoutsTab;
  setWorkoutsTab: (tab: WorkoutsTab) => void;
}

export const useUiStore = create<UiState>((set) => ({
  drawerOpen: false,
  openDrawer: () => set({ drawerOpen: true }),
  closeDrawer: () => set({ drawerOpen: false }),
  toggleDrawer: () => set((s) => ({ drawerOpen: !s.drawerOpen })),

  nutritionTab: "meals",
  setNutritionTab: (tab) => set({ nutritionTab: tab }),

  workoutsTab: "sessions",
  setWorkoutsTab: (tab) => set({ workoutsTab: tab }),
}));
