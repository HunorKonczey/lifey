"use client";

import { EmptyMealSlot } from "@/features/nutrition/components/EmptyMealSlot";

const noop = () => {};

/** The empty meal-type slot (W2.4): with the budget that still fits and a yesterday-copy chip (the canvas' dinner), budget only, and with no calorie goal or none left. */
export function EmptyMealSlotSection() {
  return (
    <div className="flex max-w-3xl flex-col gap-4">
      <div data-state="with-copy">
        <EmptyMealSlot mealType="DINNER" remainingKcal={859} copyOffer={{ kcal: 612, onCopy: noop }} onAdd={noop} />
      </div>
      <div data-state="budget-only">
        <EmptyMealSlot mealType="SNACK" remainingKcal={859} copyOffer={null} onAdd={noop} />
      </div>
      <div data-state="no-budget">
        <EmptyMealSlot mealType="BREAKFAST" remainingKcal={null} copyOffer={null} onAdd={noop} />
      </div>
      <div data-state="used-up">
        <EmptyMealSlot mealType="LUNCH" remainingKcal={-120} copyOffer={null} onAdd={noop} />
      </div>
    </div>
  );
}
