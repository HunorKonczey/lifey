"use client";

import { useRouter } from "next/navigation";
import { defaultMealType } from "../../mealTypeDefault";
import type { MealType } from "../../types";
import { AddFoodModal } from "./AddFoodModal";
import { FoodPreviewPane } from "./FoodPreviewPane";

export interface AddFoodFlowProps {
  /** Day the food is logged on (the top bar's). */
  date: Date;
  onClose: () => void;
  /** The meal type the dialog starts on — a slot's own, else the clock's. */
  mealType?: MealType;
  /** Start with this typed in the search field and this row (`food:12`) highlighted — "Log today" from the foods table. */
  initialQuery?: string;
  initialKey?: string;
}

/**
 * Add food (W2.5 + W2.6): the two-pane dialog wired to real data. Mount it to
 * open it, unmount to close — so every opening starts with a clean search.
 * From an empty result it hands the typed name to the foods tab's editor
 * (`?tab=foods&new=…`).
 */
export function AddFoodFlow({ date, onClose, mealType, initialQuery, initialKey }: AddFoodFlowProps) {
  const router = useRouter();

  return (
    <AddFoodModal
      open
      onClose={onClose}
      initialQuery={initialQuery}
      initialKey={initialKey}
      onCreate={(name) => {
        onClose();
        router.push(`/nutrition?tab=foods&new=${encodeURIComponent(name)}`);
      }}
    >
      <FoodPreviewPane date={date} initialMealType={mealType ?? defaultMealType()} onClose={onClose} />
    </AddFoodModal>
  );
}
