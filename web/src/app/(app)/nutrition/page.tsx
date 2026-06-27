"use client";

import { useState } from "react";
import { SegmentedControl } from "@/components/ui/SegmentedControl";
import { FoodsView } from "@/features/nutrition/components/FoodsView";
import { MealsView } from "@/features/nutrition/components/MealsView";
import { RecipesView } from "@/features/nutrition/components/RecipesView";

type Tab = "meals" | "foods" | "recipes";

const TABS: { value: Tab; label: string; icon: string }[] = [
  { value: "meals", label: "Meals", icon: "restaurant" },
  { value: "foods", label: "Foods", icon: "nutrition" },
  { value: "recipes", label: "Recipes", icon: "menu_book" },
];

export default function NutritionPage() {
  const [tab, setTab] = useState<Tab>("meals");

  return (
    <div className="flex flex-col gap-5">
      <SegmentedControl options={TABS} value={tab} onChange={setTab} />

      {tab === "meals" && <MealsView />}
      {tab === "foods" && <FoodsView />}
      {tab === "recipes" && <RecipesView />}
    </div>
  );
}
