"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { SegmentedControl } from "@/components/ui/SegmentedControl";
import { FoodsView } from "@/features/nutrition/components/FoodsView";
import { RecipesView } from "@/features/nutrition/components/RecipesView";
import { AssignToClientDrawer, type AssignSummaryRow } from "@/features/trainer/components/AssignToClientDrawer";
import type { RecipeResponse } from "@/features/nutrition/types";

type Tab = "foods" | "recipes";

export default function AdminNutritionPage() {
  const t = useTranslations("nutrition");
  const [tab, setTab] = useState<Tab>("recipes");
  const [assignTarget, setAssignTarget] = useState<RecipeResponse | null>(null);

  const TABS: { value: Tab; label: string; icon: string }[] = [
    { value: "recipes", label: t("recipes"), icon: "menu_book" },
    { value: "foods", label: t("foods"), icon: "nutrition" },
  ];

  const summary: AssignSummaryRow[] = (assignTarget?.ingredients ?? []).slice(0, 4).map((i) => ({
    label: i.foodName,
    detail: `${i.quantityInGrams} g`,
  }));
  const moreCount = Math.max(0, (assignTarget?.ingredients.length ?? 0) - 4);

  return (
    <div className="flex flex-col gap-5">
      <SegmentedControl options={TABS} value={tab} onChange={setTab} activeBackground="var(--tertiary)" activeColor="#161611" />

      {tab === "recipes" && <RecipesView onAssign={setAssignTarget} />}
      {tab === "foods" && <FoodsView />}

      {assignTarget && (
        <AssignToClientDrawer
          contentType="RECIPE"
          sourceId={assignTarget.id}
          title={assignTarget.name}
          summary={summary}
          moreCount={moreCount}
          onClose={() => setAssignTarget(null)}
        />
      )}
    </div>
  );
}
