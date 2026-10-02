"use client";

import { useState } from "react";
import { Button } from "@/components/ds";
import { EditMealDrawerView } from "@/features/nutrition/components/EditMealDrawer";
import type { MealResponse } from "@/features/nutrition/types";

const MEAL: MealResponse = {
  id: 1,
  dateTime: new Date(2026, 8, 27, 7, 15).toISOString(),
  mealType: "BREAKFAST",
  name: null,
  entries: [
    { foodId: 1, foodName: "Zabpehely", quantityInGrams: 60, calories: 223, protein: 8, carbs: 35, fat: 4 },
    // stored with the float noise the backend's per-100 g maths leaves behind
    { foodId: 2, foodName: "Görög joghurt 2%", quantityInGrams: 166.68518, calories: 122, protein: 16, carbs: 6, fat: 3 },
    { foodId: 3, foodName: "Áfonya", quantityInGrams: 80, calories: 46, protein: 1, carbs: 11, fat: 0 },
  ],
};

/** The edit-meal drawer (W2.7) on the canvas' breakfast; Save only logs what would be sent. */
export function EditMealDrawerSection() {
  const [open, setOpen] = useState(false);
  const [saved, setSaved] = useState<string>("—");

  return (
    <div className="flex flex-col gap-3">
      <Button onClick={() => setOpen(true)} data-testid="open-edit-meal">
        Open the meal drawer
      </Button>
      <p data-testid="saved-log" className="type-body-s">
        Saved: {saved}
      </p>
      {open && (
        <EditMealDrawerView
          meal={MEAL}
          onClose={() => setOpen(false)}
          onSave={(entries) => {
            setSaved(entries.map((e) => `${e.foodId}:${e.quantityInGrams}`).join(", "));
            setOpen(false);
          }}
        />
      )}
    </div>
  );
}
