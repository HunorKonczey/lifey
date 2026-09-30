"use client";

import { useCallback, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Button, Icon, Tabs } from "@/components/ds";
import { AddFoodFlow } from "@/features/nutrition/components/addFood/AddFoodFlow";
import { FoodsView } from "@/features/nutrition/components/FoodsView";
import { MealsView } from "@/features/nutrition/components/MealsView";
import { RecipesView } from "@/features/nutrition/components/RecipesView";
import { foodApi, recipeApi } from "@/features/nutrition/api";
import { nutritionTabHref, parseNutritionTab, type NutritionTab } from "@/features/nutrition/nutritionTab";
import { useNutritionUi } from "@/features/nutrition/nutritionUi";
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

  // Hidden foods are the one-off "enter macros" entries — not part of the user's food list.
  const { data: foods } = useQuery({ queryKey: queryKeys.foods.all(), queryFn: foodApi.list });
  const { data: recipes } = useQuery({ queryKey: queryKeys.recipes.all(), queryFn: recipeApi.list });

  const openAdd = useCallback(() => setAdding(true), []);
  usePageShortcuts({ onNew: openAdd, newLabel: t("addFood") });

  const items = [
    { value: "meals" as const, label: t("meals") },
    { value: "foods" as const, label: t("foods"), count: foods?.filter((f) => !f.hidden).length },
    { value: "recipes" as const, label: t("recipes"), count: recipes?.length },
  ];

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-wrap items-center justify-between gap-x-4 gap-y-3">
        <div className="min-w-0 flex-1">
          <Tabs<NutritionTab>
            items={items}
            value={tab}
            onChange={(next) => router.replace(nutritionTabHref(next), { scroll: false })}
            aria-label={t("tabsAria")}
          />
        </div>
        <div className="flex items-center gap-2">
          {tab === "meals" && (
            <Button variant="secondary" onClick={() => useNutritionUi.getState().setCopyOpen(true)}>
              <Icon name="event_repeat" size={20} />
              {t("copyFromDay")}
            </Button>
          )}
          <Button onClick={openAdd}>
            <Icon name="add" size={20} />
            {t("addFood")}
            <kbd className="type-label ml-1 opacity-70">N</kbd>
          </Button>
        </div>
      </div>

      {tab === "meals" && <MealsView />}
      {tab === "foods" && <FoodsView />}
      {tab === "recipes" && <RecipesView />}

      {adding && <AddFoodFlow date={date} onClose={() => setAdding(false)} />}
    </div>
  );
}
