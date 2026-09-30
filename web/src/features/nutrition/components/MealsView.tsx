"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useLocale, useTranslations } from "next-intl";
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
import { EditMealDrawer } from "./EditMealDrawer";
import { AddFoodFlow } from "./addFood/AddFoodFlow";
import { GridItem, PageGrid } from "@/components/ds";
import { DaySummaryView } from "./DaySummary";
import { EmptyMealSlot } from "./EmptyMealSlot";
import { MealCard, mealCarbs, mealFat, mealKcal, mealProtein } from "./MealCard";
import { useNutritionUi } from "../nutritionUi";
import { useCopyMeals } from "../useCopyMeals";
import type { MealResponse, MealType } from "../types";
import { useFormat } from "@/lib/i18n/format";

export function MealsView() {
  const t = useTranslations("nutrition");
  const fmt = useFormat();
  const locale = useLocale();
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

  const MEAL_GROUPS: { type: MealType; label: string }[] = [
    { type: "BREAKFAST", label: t("breakfast") },
    { type: "LUNCH", label: t("lunch") },
    { type: "SNACK", label: t("snack") },
    { type: "DINNER", label: t("dinner") },
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

  // "Yesterday's dinner" on an empty slot: copy + toast with Undo.
  const copySlot = useCopyMeals(date);

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
  const goalKcal = settings?.dailyCalorieGoal ?? null;
  const remainingKcal = goalKcal != null ? goalKcal - totalKcal : null;
  const summary = (
    <DaySummaryView
      kcal={totalKcal}
      goalKcal={goalKcal}
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
        {MEAL_GROUPS.map(({ type, label }) => {
          const meals = todayMeals.filter((m) => m.mealType === type);
          const prevMeals = previousDayMeals.filter((m) => m.mealType === type);
          // "Yesterday" is only a meaningful label while viewing today —
          // browsing a past day would make the wording ambiguous, so the
          // shortcut only appears there.
          const canCopyYesterday = meals.length === 0 && prevMeals.length > 0 && isToday(date);

          // A logged meal type is just its cards (each carries the type's icon and name);
          // a type with nothing logged is a quiet slot with the budget that still fits (W2.4).
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
            <EmptyMealSlot
              key={type}
              mealType={type}
              remainingKcal={remainingKcal}
              copyOffer={
                canCopyYesterday
                  ? {
                      kcal: Math.round(prevMeals.reduce((sum, m) => sum + mealKcal(m), 0)),
                      pending: copySlot.isPending,
                      onCopy: () =>
                        copySlot.mutate({ meals: prevMeals, message: t("slotCopied", { meal: label.toLocaleLowerCase(locale) }) }),
                    }
                  : null
              }
              onAdd={() => setAddingTo(type)}
            />
          );
        })}
      </GridItem>

      {/* Daily summary — sticky beside the list from 1280 */}
      <GridItem span={{ base: 4, md: 8, xl: 4 }} order={{ base: 0, xl: 1 }}>
        <div className="xl:sticky xl:top-6">{summary}</div>
      </GridItem>

      {addingTo && <AddFoodFlow date={date} mealType={addingTo} onClose={() => setAddingTo(null)} />}

      {editingMeal && <EditMealDrawer meal={editingMeal} onClose={() => setEditingMeal(null)} />}

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
