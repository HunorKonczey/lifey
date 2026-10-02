"use client";

import { useRef, useState } from "react";
import { Button } from "@/components/ds";
import { DaySummaryView } from "@/features/nutrition/components/DaySummary";
import { MealCard } from "@/features/nutrition/components/MealCard";
import { NutritionHeader } from "@/features/nutrition/components/NutritionHeader";
import type { NutritionTab } from "@/features/nutrition/nutritionTab";
import type { MealResponse } from "@/features/nutrition/types";
import { useToast } from "@/lib/hooks/useToast";

const at = (h: number, m: number) => new Date(2026, 8, 27, h, m).toISOString();
const entry = (foodId: number, foodName: string, quantityInGrams: number, calories: number, protein: number, carbs: number, fat: number) => ({
  foodId,
  foodName,
  quantityInGrams,
  calories,
  protein,
  carbs,
  fat,
});

const BREAKFAST: MealResponse = {
  id: 1,
  dateTime: at(7, 15),
  mealType: "BREAKFAST",
  name: null,
  entries: [entry(1, "Zabpehely", 60, 223, 8, 35, 4), entry(2, "Görög joghurt 2%", 150, 110, 15, 5.4, 3), entry(3, "Áfonya", 80, 46, 1, 11, 0.2)],
};

/**
 * Nutrition on a phone (W2.12, W2-F): the tab row as a segmented control with the FAB, the compact day
 * summary and a meal card with its "150 g · F 15" rows. Resize to 390 px; "Show delete toast" raises the
 * undo toast that has to clear the FAB and the bottom nav.
 */
export function NutritionMobileSection() {
  const [tab, setTab] = useState<NutritionTab>("meals");
  const [copying, setCopying] = useState(false);
  const [log, setLog] = useState("—");
  const copyAnchor = useRef<HTMLSpanElement>(null);

  return (
    <div className="flex max-w-md flex-col gap-4" data-testid="nutrition-mobile">
      <NutritionHeader
        tab={tab}
        onTabChange={setTab}
        counts={{ foods: 18, recipes: 4 }}
        copying={copying}
        onToggleCopy={() => {
          setCopying((c) => !c);
          setLog("copy");
        }}
        copyAnchor={copyAnchor}
        onNewRecipe={() => setLog("new recipe")}
        onAddFood={() => setLog("add food")}
      />
      <p data-testid="mobile-log" className="type-body-s">
        Last action: {log} · tab: {tab}
      </p>
      <DaySummaryView
        kcal={1041}
        goalKcal={1900}
        macros={{ protein: { value: 68, goal: 120 }, carbs: { value: 112, goal: 210 }, fat: { value: 34, goal: 63 } }}
      />
      <MealCard meal={BREAKFAST} onAdd={() => {}} onEdit={() => {}} onDuplicate={() => {}} onDelete={() => {}} onDeleteItem={() => {}} />
      <Button variant="secondary" onClick={() => useToast.getState().showUndo("Snack törölve", () => {}, () => {})}>
        Show delete toast
      </Button>
    </div>
  );
}
