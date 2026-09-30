"use client";

import { useCallback, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { AddFoodFlow } from "@/features/nutrition/components/addFood/AddFoodFlow";
import { CopyFromDayPopover } from "@/features/nutrition/components/CopyFromDayPopover";
import { NutritionHeader } from "@/features/nutrition/components/NutritionHeader";
import { FoodsView } from "@/features/nutrition/components/FoodsView";
import { MealsView } from "@/features/nutrition/components/MealsView";
import { RecipesView } from "@/features/nutrition/components/RecipesView";
import { foodApi, recipeApi } from "@/features/nutrition/api";
import { nutritionTabHref, parseNutritionTab } from "@/features/nutrition/nutritionTab";
import { queryKeys } from "@/lib/api/queryKeys";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { usePageShortcuts } from "@/lib/hooks/usePageShortcuts";

/**
 * The nutrition page (W2.1, W2-A): tabs with their counts, the copy-from-day
 * and add-food actions to the right of them, and the active tab in the URL
 * (`?tab=foods`) so links, reloads and the back button keep it. `N` adds a
 * food on every tab.
 */
export default function NutritionPage() {
  const t = useTranslations("nutrition");
  const router = useRouter();
  const tab = parseNutritionTab(useSearchParams().get("tab"));
  const { date } = useDateStore();
  const [adding, setAdding] = useState(false);
  const [copying, setCopying] = useState(false);
  const [creatingRecipe, setCreatingRecipe] = useState(false);
  const copyAnchor = useRef<HTMLSpanElement>(null);

  // Hidden foods are the one-off "enter macros" entries — not part of the user's food list.
  const { data: foods } = useQuery({ queryKey: queryKeys.foods.all(), queryFn: foodApi.list });
  const { data: recipes } = useQuery({ queryKey: queryKeys.recipes.all(), queryFn: recipeApi.list });

  const openAdd = useCallback(() => setAdding(true), []);
  usePageShortcuts({ onNew: openAdd, newLabel: t("addFood") });

  return (
    <div className="flex flex-col gap-5">
      <NutritionHeader
        tab={tab}
        onTabChange={(next) => router.replace(nutritionTabHref(next), { scroll: false })}
        counts={{ foods: foods?.filter((f) => !f.hidden).length, recipes: recipes?.length }}
        copying={copying}
        onToggleCopy={() => setCopying((o) => !o)}
        copyAnchor={copyAnchor}
        onNewRecipe={() => setCreatingRecipe(true)}
        onAddFood={openAdd}
      />

      {tab === "meals" && <MealsView />}
      {tab === "foods" && <FoodsView />}
      {tab === "recipes" && <RecipesView creating={creatingRecipe} onCreatingChange={setCreatingRecipe} />}

      <CopyFromDayPopover open={copying} onClose={() => setCopying(false)} anchorRef={copyAnchor} date={date} />

      {adding && <AddFoodFlow date={date} onClose={() => setAdding(false)} />}
    </div>
  );
}
