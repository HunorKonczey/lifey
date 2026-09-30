"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { format, subDays, isToday } from "date-fns";
import { mealApi } from "../api";
import { copyMealPayload } from "../copyMeal";
import { settingsApi } from "@/features/settings/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { useToast } from "@/lib/hooks/useToast";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import { AddMealEntryDialog } from "./AddMealEntryDialog";
import { GridItem, PageGrid } from "@/components/ds";
import { MEAL_TYPE_STYLE } from "../mealTypeStyle";
import { DaySummaryView } from "./DaySummary";
import { MealCard, mealCarbs, mealFat, mealKcal, mealProtein } from "./MealCard";
import { useNutritionUi } from "../nutritionUi";
import type { MealResponse, MealType } from "../types";
import { useFormat } from "@/lib/i18n/format";

export function MealsView() {
  const t = useTranslations("nutrition");
  const fmt = useFormat();
  const { date } = useDateStore();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const dateStr = format(date, "yyyy-MM-dd");
  const prevDateStr = format(subDays(date, 1), "yyyy-MM-dd");
  const [addingTo, setAddingTo] = useState<MealType | null>(null);
  const [editingMeal, setEditingMeal] = useState<MealResponse | null>(null);
  // Opened by the page header's "Copy from an earlier day" as well as the summary panel's button.
  const copyingPreviousDay = useNutritionUi((s) => s.copyOpen);
  const setCopyingPreviousDay = useNutritionUi((s) => s.setCopyOpen);
  // Deleting used to fire on the first click with no way back (docs/redesign/web-redesign-prompt.md).
  const [removingMeal, setRemovingMeal] = useState<MealResponse | null>(null);

  const MEAL_GROUPS: { type: MealType; label: string; icon: string }[] = [
    { type: "BREAKFAST", label: t("breakfast"), icon: MEAL_TYPE_STYLE.BREAKFAST.icon },
    { type: "LUNCH", label: t("lunch"), icon: MEAL_TYPE_STYLE.LUNCH.icon },
    { type: "SNACK", label: t("snack"), icon: MEAL_TYPE_STYLE.SNACK.icon },
    { type: "DINNER", label: t("dinner"), icon: MEAL_TYPE_STYLE.DINNER.icon },
  ];

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.meals.all(),
    queryFn: mealApi.list,
  });

  const { data: settings } = useQuery({
    queryKey: queryKeys.settings.all(),
    queryFn: settingsApi.get,
    staleTime: 5 * 60_000,
  });

  const deleteMutation = useMutation({
    mutationFn: (id: number) => mealApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.meals.all() });
      show(t("mealRemoved"), "success");
    },
    onError: () => show(t("removeFailed"), "error"),
    onSettled: () => setRemovingMeal(null),
  });

  const duplicateMutation = useMutation({
    // Lands on the currently viewed day, not "now" — duplicating while
    // browsing a past day should stay on that day.
    mutationFn: (meal: MealResponse) => mealApi.create(copyMealPayload(meal, date)),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.meals.all() });
      show(t("mealDuplicated"), "success");
    },
    onError: () => show(t("duplicateMealFailed"), "error"),
  });

  const copyMealsMutation = useMutation({
    mutationFn: async (mealsToCopy: MealResponse[]) => {
      await Promise.all(mealsToCopy.map((m) => mealApi.create(copyMealPayload(m, date))));
      return mealsToCopy.length;
    },
    onSuccess: (count) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.meals.all() });
      show(t("mealsCopied", { count }), "success");
      setCopyingPreviousDay(false);
    },
    onError: () => show(t("copyDayFailed"), "error"),
  });

  const todayMeals = (data ?? []).filter(
    (m) => format(new Date(m.dateTime), "yyyy-MM-dd") === dateStr,
  );
  const previousDayMeals = (data ?? []).filter(
    (m) => format(new Date(m.dateTime), "yyyy-MM-dd") === prevDateStr,
  );
  const previousDayKcal = previousDayMeals.reduce((s, m) => s + mealKcal(m), 0);

  const totalKcal = todayMeals.reduce((sum, m) => sum + mealKcal(m), 0);
  const summary = (
    <DaySummaryView
      kcal={totalKcal}
      goalKcal={settings?.dailyCalorieGoal ?? null}
      macros={{
        protein: { value: todayMeals.reduce((sum, m) => sum + mealProtein(m), 0), goal: settings?.dailyProteinGoal ?? null },
        carbs: { value: todayMeals.reduce((sum, m) => sum + mealCarbs(m), 0), goal: settings?.dailyCarbsGoal ?? null },
        fat: { value: todayMeals.reduce((sum, m) => sum + mealFat(m), 0), goal: settings?.dailyFatGoal ?? null },
      }}
    />
  );

  if (isLoading) {
    return (
      <PageGrid>
        <GridItem span={{ base: 4, md: 8, xl: 8 }} order={{ base: 1, xl: 0 }}>
          <div className="flex flex-col gap-3">
            {[0, 1, 2, 3].map((i) => <Skeleton key={i} variant="card" className="h-24" />)}
          </div>
        </GridItem>
        <GridItem span={{ base: 4, md: 8, xl: 4 }} order={{ base: 0, xl: 1 }}>
          <Skeleton variant="card" className="h-72" />
        </GridItem>
      </PageGrid>
    );
  }

  if (isError) return <ErrorState onRetry={refetch} />;

  return (
    // 8 + 4 from 1280 (the summary sticky); below that the summary sits above the list (W2-A/B/F).
    <PageGrid>
      {/* Meal groups */}
      <GridItem span={{ base: 4, md: 8, xl: 8 }} order={{ base: 1, xl: 0 }} className="flex flex-col gap-6">
        {MEAL_GROUPS.map(({ type, label, icon }) => {
          const meals = todayMeals.filter((m) => m.mealType === type);
          const prevMeals = previousDayMeals.filter((m) => m.mealType === type);
          // "Yesterday" is only a meaningful label while viewing today —
          // browsing a past day would make the wording ambiguous, so the
          // shortcut only appears there.
          const canCopyYesterday = meals.length === 0 && prevMeals.length > 0 && isToday(date);

          // A logged meal type is just its cards (each carries the type's icon and name);
          // a type with nothing logged keeps the dashed slot until W2.4 replaces it.
          if (meals.length > 0) {
            return (
              <div key={type} className="flex flex-col gap-3">
                {meals.map((meal) => (
                  <MealCard
                    key={meal.id}
                    meal={meal}
                    onAdd={() => setAddingTo(type)}
                    onEdit={() => setEditingMeal(meal)}
                    onDuplicate={() => duplicateMutation.mutate(meal)}
                    onDelete={() => setRemovingMeal(meal)}
                    isDeleting={deleteMutation.isPending && deleteMutation.variables === meal.id}
                  />
                ))}
              </div>
            );
          }

          return (
            <div key={type} className="flex flex-col gap-2">
              <div className="flex items-center gap-2 px-1">
                <span className="material-symbols-rounded text-xl" style={{ color: MEAL_TYPE_STYLE[type].color }}>{icon}</span>
                <span className="font-bold text-sm">{label}</span>
              </div>
              <button
                onClick={() => setAddingTo(type)}
                className="w-full py-2.5 rounded-[var(--r-md)] text-sm font-semibold flex items-center justify-center gap-1 transition-colors hover:bg-surface-container"
                style={{ border: "1px dashed var(--outline)", color: "var(--on-surface-variant)" }}
              >
                <span className="material-symbols-rounded text-lg">add</span> {t("addTo", { meal: label })}
              </button>
              {canCopyYesterday && (
                <button
                  onClick={() => copyMealsMutation.mutate(prevMeals)}
                  disabled={copyMealsMutation.isPending}
                  className="w-full py-2.5 rounded-[var(--r-md)] text-sm font-semibold flex items-center justify-center gap-1 transition-colors hover:bg-surface-container disabled:opacity-50"
                  style={{ border: "1px dashed var(--outline)", color: "var(--on-surface-variant)" }}
                >
                  <span className="material-symbols-rounded text-lg">content_copy</span>
                  {t("copyPreviousDayGhost", {
                    meal: label,
                    kcal: Math.round(prevMeals.reduce((sum, m) => sum + mealKcal(m), 0)),
                  })}
                </button>
              )}
            </div>
          );
        })}
      </GridItem>

      {/* Daily summary — sticky beside the list from 1280 */}
      <GridItem span={{ base: 4, md: 8, xl: 4 }} order={{ base: 0, xl: 1 }}>
        <div className="xl:sticky xl:top-6">{summary}</div>
      </GridItem>

      {addingTo && (
        <AddMealEntryDialog mealType={addingTo} date={date} onClose={() => setAddingTo(null)} />
      )}

      {editingMeal && (
        <AddMealEntryDialog
          mealType={editingMeal.mealType}
          date={new Date(editingMeal.dateTime)}
          meal={editingMeal}
          onClose={() => setEditingMeal(null)}
        />
      )}

      <ConfirmDialog
        open={copyingPreviousDay}
        title={t("copyPreviousDayConfirmTitle")}
        body={t("copyPreviousDayConfirmBody", {
          count: previousDayMeals.length,
          kcal: Math.round(previousDayKcal),
          date: fmt.date(subDays(date, 1), "day"),
        })}
        confirmLabel={t("copyPreviousDay")}
        confirming={copyMealsMutation.isPending}
        onConfirm={() => copyMealsMutation.mutate(previousDayMeals)}
        onCancel={() => setCopyingPreviousDay(false)}
      />

      <ConfirmDialog
        open={removingMeal != null}
        title={t("removeMealConfirmTitle")}
        body={removingMeal ? t("removeMealConfirmBody", {
          kcal: Math.round(removingMeal.entries.reduce((sum, e) => sum + e.calories, 0)),
          count: removingMeal.entries.length,
        }) : ""}
        confirmLabel={t("removeMealAria")}
        confirming={deleteMutation.isPending}
        onConfirm={() => removingMeal && deleteMutation.mutate(removingMeal.id)}
        onCancel={() => setRemovingMeal(null)}
      />
    </PageGrid>
  );
}
