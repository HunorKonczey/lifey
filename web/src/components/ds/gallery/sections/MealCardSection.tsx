"use client";

import { MealCard } from "@/features/nutrition/components/MealCard";
import type { MealResponse } from "@/features/nutrition/types";

const noop = () => {};

const entry = (foodId: number, foodName: string, quantityInGrams: number, calories: number, protein: number, carbs: number, fat: number) => ({
  foodId,
  foodName,
  quantityInGrams,
  calories,
  protein,
  carbs,
  fat,
});

// 2026-09-27 at 07:15 local
const at = (h: number, m: number) => new Date(2026, 8, 27, h, m).toISOString();

const BREAKFAST: MealResponse = {
  id: 1,
  dateTime: at(7, 15),
  mealType: "BREAKFAST",
  name: null,
  entries: [
    entry(1, "Zabpehely", 60, 223, 8, 35, 4),
    entry(2, "Görög joghurt 2%", 150, 110, 15, 5.4, 3),
    // a long name that has to wrap, never truncate
    entry(3, "Teljes kiőrlésű, magvas kenyér vajjal, paradicsommal és füstölt sajttal", 80, 46, 1, 11, 0.2),
  ],
};

const LUNCH_RECIPE: MealResponse = {
  id: 2,
  dateTime: at(12, 30),
  mealType: "LUNCH",
  name: "Csirkés rizstál brokkolival",
  entries: [entry(4, "Csirkemell", 150, 248, 46, 0, 5), entry(5, "Barna rizs", 180, 222, 5, 46, 2), entry(6, "Brokkoli", 90, 58, 1, 11, 0)],
};

const SNACK: MealResponse = { id: 3, dateTime: at(15, 40), mealType: "SNACK", name: null, entries: [entry(7, "Alma", 180, 94, 0.5, 25, 0.3)] };

/** The meal card (W2.3): a multi-item breakfast (one very long name), a recipe lunch, a one-item snack, and a read-only card (no handlers — the trainer's view). */
export function MealCardSection() {
  return (
    <div className="grid gap-6 lg:grid-cols-2">
      <div className="flex flex-col gap-4" data-state="editable">
        <MealCard meal={BREAKFAST} onAdd={noop} onEdit={noop} onDuplicate={noop} onDelete={noop} />
        <MealCard meal={LUNCH_RECIPE} onAdd={noop} onEdit={noop} onDuplicate={noop} onDelete={noop} />
        <MealCard meal={SNACK} onAdd={noop} onEdit={noop} onDuplicate={noop} onDelete={noop} />
      </div>
      <div data-state="read-only">
        <MealCard meal={BREAKFAST} />
      </div>
    </div>
  );
}
