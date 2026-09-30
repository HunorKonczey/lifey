import { create } from "zustand";

/** Transient UI state shared between the nutrition page header and the meals
 *  tab — the header's "copy from an earlier day" button opens what the meals
 *  tab owns. (W2.9 replaces the confirm this drives with a popover.) */
interface NutritionUiState {
  copyOpen: boolean;
  setCopyOpen: (open: boolean) => void;
}

export const useNutritionUi = create<NutritionUiState>((set) => ({
  copyOpen: false,
  setCopyOpen: (copyOpen) => set({ copyOpen }),
}));
