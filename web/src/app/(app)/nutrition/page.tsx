"use client";

import { useTranslations } from "next-intl";
import { SegmentedControl } from "@/components/ui/SegmentedControl";
import { FoodsView } from "@/features/nutrition/components/FoodsView";
import { MealsView } from "@/features/nutrition/components/MealsView";
import { RecipesView } from "@/features/nutrition/components/RecipesView";
import { useUiStore } from "@/lib/hooks/useUiStore";

type Tab = "meals" | "foods" | "recipes";

export default function NutritionPage() {
  const t = useTranslations("nutrition");
  const tab = useUiStore((s) => s.nutritionTab);
  const setTab = useUiStore((s) => s.setNutritionTab);

  const TABS: { value: Tab; label: string; icon: string }[] = [
    { value: "meals", label: t("meals"), icon: "restaurant" },
    { value: "foods", label: t("foods"), icon: "nutrition" },
    { value: "recipes", label: t("recipes"), icon: "menu_book" },
  ];

  return (
    <div className="flex flex-col gap-5">
      <SegmentedControl options={TABS} value={tab} onChange={setTab} />

      {tab === "meals" && <MealsView />}
      {tab === "foods" && <FoodsView />}
      {tab === "recipes" && <RecipesView />}
    </div>
  );
}
