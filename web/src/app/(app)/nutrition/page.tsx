"use client";

import { SegmentedControl } from "@/components/ui/SegmentedControl";
import { FoodsView } from "@/features/nutrition/components/FoodsView";
import { MealsView } from "@/features/nutrition/components/MealsView";
import { RecipesView } from "@/features/nutrition/components/RecipesView";
import { useUiStore } from "@/lib/hooks/useUiStore";

type Tab = "meals" | "foods" | "recipes";

const TABS: { value: Tab; label: string; icon: string }[] = [
  { value: "meals", label: "Meals", icon: "restaurant" },
  { value: "foods", label: "Foods", icon: "nutrition" },
  { value: "recipes", label: "Recipes", icon: "menu_book" },
];

export default function NutritionPage() {
  const tab = useUiStore((s) => s.nutritionTab);
  const setTab = useUiStore((s) => s.setNutritionTab);

  return (
    <div className="flex flex-col gap-5">
      <SegmentedControl options={TABS} value={tab} onChange={setTab} />

      {tab === "meals" && <MealsView />}
      {tab === "foods" && <FoodsView />}
      {tab === "recipes" && <RecipesView />}
    </div>
  );
}
