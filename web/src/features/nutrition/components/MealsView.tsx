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
import { TOAST_DURATION_MS, useToast } from "@/lib/hooks/useToast";
import { useUndoableDelete } from "@/lib/hooks/useUndoableDelete";
import { keepalivePut } from "@/lib/api/client";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";
import { EditMealDrawer } from "./EditMealDrawer";
import { AddFoodFlow } from "./addFood/AddFoodFlow";
import { ConfirmModal, GridItem, PageGrid } from "@/components/ds";
import { DaySummaryView } from "./DaySummary";
import { EmptyMealSlot } from "./EmptyMealSlot";
import { MealCard, mealCarbs, mealFat, mealKcal, mealProtein } from "./MealCard";
import { useCopyMeals } from "../useCopyMeals";
import type { MealResponse, MealType } from "../types";
import { useFormat } from "@/lib/i18n/format";

export function MealsView() {
  const t = useTranslations("nutrition");
  const common = useTranslations("common");
  const fmt = useFormat();
  const locale = useLocale();
  const { date } = useDateStore();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const dateStr = format(date, "yyyy-MM-dd");
  const prevDateStr = format(subDays(date, 1), "yyyy-MM-dd");
  const [addingTo, setAddingTo] = useState<MealType | null>(null);
  const [editingMeal, setEditingMeal] = useState<MealResponse | null>(null);
  // Deleting used to fire on the first click with no way back (docs/redesign/web-redesign-prompt.md).
  const [removingMeal, setRemovingMeal] = useState<MealResponse | null>(null);
  const [removingItem, setRemovingItem] = useState<{ meal: MealResponse; index: number } | null>(null);
  const undoableDelete = useUndoableDelete();
  const undoSeconds = TOAST_DURATION_MS / 1000;

  const MEAL_GROUPS: { type: MealType; label: string }[] = [
    { type: "BREAKFAST", label: t("breakfast") },
    { type: "LUNCH", label: t("lunch") },
    { type: "SNACK", label: t("snack") },
    { type: "DINNER", label: t("dinner") },
  ];

  const mealLabel = (type: MealType) => MEAL_GROUPS.find((g) => g.type === type)!.label;

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.meals.all(),
    queryFn: mealApi.list,
  });

  const { data: settings } = useQuery({
    queryKey: queryKeys.settings.all(),
    queryFn: settingsApi.get,
    staleTime: 5 * 60_000,
  });

  const setCachedMeals = (update: (meals: MealResponse[]) => MealResponse[]) =>
    queryClient.setQueryData<MealResponse[]>(queryKeys.meals.all(), (old) => update(old ?? []));

  // Delete = confirm, then the meal leaves the list at once and a toast offers Undo; the real DELETE
  // goes out only when the 6 s window closes (or the tab is left). Undo never touches the network.
  const deleteMeal = (meal: MealResponse) =>
    undoableDelete({
      message: t("mealDeleted", { meal: mealLabel(meal.mealType) }),
      path: `/meals/${meal.id}`,
      remove: () => setCachedMeals((list) => list.filter((m) => m.id !== meal.id)),
      restore: () => setCachedMeals((list) => (list.some((m) => m.id === meal.id) ? list : [...list, meal])),
      errorMessage: t("removeFailed"),
    });

  // One food out of a meal is a PUT of the rest, deferred the same way; the last food takes the meal with it.
  const deleteItem = (meal: MealResponse, index: number) => {
    if (meal.entries.length <= 1) return deleteMeal(meal);
    const remaining = meal.entries.filter((_, i) => i !== index);
    undoableDelete({
      message: t("itemDeleted", { food: meal.entries[index].foodName }),
      remove: () => setCachedMeals((list) => list.map((m) => (m.id === meal.id ? { ...m, entries: remaining } : m))),
      restore: () => setCachedMeals((list) => list.map((m) => (m.id === meal.id ? meal : m))),
      commit: async () => {
        await keepalivePut(`/meals/${meal.id}`, {
          dateTime: meal.dateTime,
          mealType: meal.mealType,
          name: meal.name,
          entries: remaining.map((e) => ({ foodId: e.foodId, quantityInGrams: e.quantityInGrams })),
        });
        queryClient.invalidateQueries({ queryKey: queryKeys.meals.all() });
      },
      errorMessage: t("removeFailed"),
    });
  };

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

  const todayMeals = (data ?? []).filter(
    (m) => format(new Date(m.dateTime), "yyyy-MM-dd") === dateStr,
  );
  const previousDayMeals = (data ?? []).filter(
    (m) => format(new Date(m.dateTime), "yyyy-MM-dd") === prevDateStr,
  );

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
                    onDeleteItem={(index) => setRemovingItem({ meal, index })}
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

      <ConfirmModal
        open={removingMeal != null}
        onClose={() => setRemovingMeal(null)}
        onConfirm={() => {
          if (removingMeal) deleteMeal(removingMeal);
          setRemovingMeal(null);
        }}
        icon="delete"
        title={removingMeal ? t("deleteMealTitle", { meal: removingMeal.mealType }) : ""}
        body={
          removingMeal
            ? t("deleteMealBody", {
                count: removingMeal.entries.length,
                kcal: Math.round(mealKcal(removingMeal)),
                seconds: undoSeconds,
              })
            : ""
        }
        cancelLabel={common("cancel")}
        confirmLabel={common("delete")}
      />

      <ConfirmModal
        open={removingItem != null}
        onClose={() => setRemovingItem(null)}
        onConfirm={() => {
          if (removingItem) deleteItem(removingItem.meal, removingItem.index);
          setRemovingItem(null);
        }}
        icon="delete"
        title={removingItem ? t("deleteItemTitle", { food: removingItem.meal.entries[removingItem.index].foodName }) : ""}
        body={
          removingItem
            ? removingItem.meal.entries.length <= 1
              ? t("deleteItemLastBody", { seconds: undoSeconds })
              : t("deleteItemBody", {
                  grams: fmt.number(removingItem.meal.entries[removingItem.index].quantityInGrams, 1),
                  kcal: Math.round(removingItem.meal.entries[removingItem.index].calories),
                  seconds: undoSeconds,
                })
            : ""
        }
        cancelLabel={common("cancel")}
        confirmLabel={common("delete")}
      />
    </PageGrid>
  );
}
