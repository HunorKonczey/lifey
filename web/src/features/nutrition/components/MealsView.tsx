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
import { MealCard, mealKcal, mealProtein } from "./MealCard";
import { computeRemainingBudget, isOver, remainingOf } from "../budget";
import type { MealResponse, MealType } from "../types";

export function MealsView() {
  const t = useTranslations("nutrition");
  const d = useTranslations("dashboard");
  const { date } = useDateStore();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const dateStr = format(date, "yyyy-MM-dd");
  const prevDateStr = format(subDays(date, 1), "yyyy-MM-dd");
  const [addingTo, setAddingTo] = useState<MealType | null>(null);
  const [editingMeal, setEditingMeal] = useState<MealResponse | null>(null);
  const [copyingPreviousDay, setCopyingPreviousDay] = useState(false);

  const MEAL_GROUPS: { type: MealType; label: string; icon: string }[] = [
    { type: "BREAKFAST", label: t("breakfast"), icon: "bakery_dining" },
    { type: "LUNCH", label: t("lunch"), icon: "lunch_dining" },
    { type: "DINNER", label: t("dinner"), icon: "dinner_dining" },
    { type: "SNACK", label: t("snack"), icon: "icecream" },
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

  const totalKcal = todayMeals.reduce((s, m) => s + mealKcal(m), 0);
  const totalProtein = todayMeals.reduce((s, m) => s + mealProtein(m), 0);
  const totalItems = todayMeals.reduce((s, m) => s + m.entries.length, 0);

  const budget = computeRemainingBudget(
    { calories: totalKcal, protein: totalProtein },
    { dailyCalorieGoal: settings?.dailyCalorieGoal ?? null, dailyProteinGoal: settings?.dailyProteinGoal ?? null },
  );
  const remainingKcal = remainingOf(budget.calories);
  const remainingProtein = remainingOf(budget.protein);

  if (isLoading) {
    return (
      <div className="flex gap-6">
        <div className="flex-1 flex flex-col gap-3">
          {[0, 1, 2, 3].map((i) => <Skeleton key={i} variant="card" className="h-24" />)}
        </div>
        <Skeleton variant="card" className="w-[300px] h-80" />
      </div>
    );
  }

  if (isError) return <ErrorState onRetry={refetch} />;

  return (
    <div className="flex gap-6">
      {/* Meal groups */}
      <div className="flex-1 min-w-0 flex flex-col gap-6">
        {MEAL_GROUPS.map(({ type, label, icon }) => {
          const meals = todayMeals.filter((m) => m.mealType === type);
          const groupKcal = meals.reduce((s, m) => s + mealKcal(m), 0);
          const prevMeals = previousDayMeals.filter((m) => m.mealType === type);
          // "Yesterday" is only a meaningful label while viewing today —
          // browsing a past day would make the wording ambiguous, so the
          // shortcut only appears there (the panel's "Copy previous day"
          // below works for any viewed day).
          const canCopyYesterday = meals.length === 0 && prevMeals.length > 0 && isToday(date);
          return (
            <div key={type} className="flex flex-col gap-2">
              {/* Section header */}
              <div className="flex items-center gap-2 px-1">
                <span className="material-symbols-rounded text-xl" style={{ color: "var(--metric-kcal)" }}>{icon}</span>
                <span className="font-bold text-sm">{label}</span>
                {groupKcal > 0 && (
                  <span className="ml-auto text-sm font-semibold tabular" style={{ color: "var(--metric-kcal)" }}>
                    {Math.round(groupKcal)} kcal
                  </span>
                )}
              </div>

              {/* Meal cards */}
              {meals.map((meal) => (
                <MealCard
                  key={meal.id}
                  meal={meal}
                  onEdit={() => setEditingMeal(meal)}
                  onDuplicate={() => duplicateMutation.mutate(meal)}
                  onDelete={() => deleteMutation.mutate(meal.id)}
                  isDeleting={deleteMutation.isPending && deleteMutation.variables === meal.id}
                />
              ))}

              {/* Add button */}
              <button
                onClick={() => setAddingTo(type)}
                className="w-full py-2.5 rounded-[var(--r-md)] text-sm font-semibold flex items-center justify-center gap-1 transition-colors hover:bg-surface-container"
                style={{ border: "1px dashed var(--outline)", color: "var(--on-surface-variant)" }}
              >
                <span className="material-symbols-rounded text-lg">add</span> {t("addTo", { meal: label })}
              </button>

              {/* Copy yesterday's meals of this type */}
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
                    kcal: Math.round(prevMeals.reduce((s, m) => s + mealKcal(m), 0)),
                  })}
                </button>
              )}
            </div>
          );
        })}
      </div>

      {/* Daily summary sticky panel */}
      <div className="w-[300px] shrink-0">
        <div className="sticky top-6 rounded-[var(--r-lg)] p-5" style={{ background: "var(--surface)" }}>
          <p className="text-sm font-bold mb-4">{t("dailySummary")}</p>

          {/* Prominent "what's left today" line — hidden metric-by-metric
              when its goal isn't set, whole block hidden without any goal. */}
          {(remainingKcal != null || remainingProtein != null) && (
            <div className="flex flex-col gap-0.5 mb-3">
              {remainingKcal != null && (
                <p
                  className="text-base font-extrabold tabular"
                  style={{ color: isOver(budget.calories) ? "var(--goal-negative)" : "var(--goal-positive)" }}
                >
                  {isOver(budget.calories)
                    ? d("over", { diff: Math.abs(Math.round(remainingKcal)), unit: "kcal" })
                    : d("remaining", { diff: Math.round(remainingKcal), unit: "kcal" })}
                </p>
              )}
              {remainingProtein != null && (
                <p
                  className="text-sm font-semibold tabular"
                  style={{ color: isOver(budget.protein) ? "var(--goal-negative)" : "var(--on-surface-variant)" }}
                >
                  {isOver(budget.protein)
                    ? d("over", { diff: Math.abs(Math.round(remainingProtein)), unit: "g protein" })
                    : d("remaining", { diff: Math.round(remainingProtein), unit: "g protein" })}
                </p>
              )}
            </div>
          )}

          <div className="flex items-end gap-2 mb-1">
            <span className="text-3xl font-extrabold tabular">
              {Math.round(totalKcal).toLocaleString()}
            </span>
            {budget.calories.goal != null ? (
              <span className="text-sm font-semibold mb-1" style={{ color: "var(--on-surface-variant)" }}>
                / {budget.calories.goal.toLocaleString()} kcal
              </span>
            ) : (
              <span className="text-sm mb-1" style={{ color: "var(--on-surface-variant)" }}>kcal</span>
            )}
          </div>
          {budget.calories.goal != null && (
            <div className="h-2 rounded-[var(--r-pill)] overflow-hidden mb-4" style={{ background: "var(--surface-highest)" }}>
              <div
                className="h-full rounded-[var(--r-pill)] transition-all"
                style={{
                  width: `${Math.min(totalKcal / budget.calories.goal, 1) * 100}%`,
                  background: isOver(budget.calories) ? "var(--goal-negative)" : "var(--metric-kcal)",
                }}
              />
            </div>
          )}

          <div className="flex justify-between text-xs mb-1">
            <span style={{ color: "var(--metric-protein)" }}>{d("protein")}</span>
            <span className="tabular" style={{ color: "var(--on-surface-variant)" }}>
              {budget.protein.goal != null
                ? `${Math.round(totalProtein)} / ${budget.protein.goal}g`
                : `${Math.round(totalProtein)}g`}
            </span>
          </div>
          {budget.protein.goal != null && (
            <div className="h-1.5 rounded-[var(--r-pill)] overflow-hidden mb-4" style={{ background: "var(--surface-highest)" }}>
              <div
                className="h-full rounded-[var(--r-pill)]"
                style={{
                  width: `${Math.min(totalProtein / budget.protein.goal, 1) * 100}%`,
                  background: isOver(budget.protein) ? "var(--goal-negative)" : "var(--metric-protein)",
                }}
              />
            </div>
          )}

          <div className="flex justify-between pt-3 text-sm" style={{ borderTop: "1px solid var(--outline)" }}>
            <span style={{ color: "var(--on-surface-variant)" }}>{t("mealsCount")}</span>
            <span className="font-semibold tabular">{todayMeals.length}</span>
          </div>
          <div className="flex justify-between text-sm">
            <span style={{ color: "var(--on-surface-variant)" }}>{t("items")}</span>
            <span className="font-semibold tabular">{totalItems}</span>
          </div>

          {previousDayMeals.length > 0 && (
            <button
              onClick={() => setCopyingPreviousDay(true)}
              className="w-full mt-4 py-2 rounded-[var(--r-md)] text-sm font-semibold flex items-center justify-center gap-1 transition-colors hover:bg-surface-container"
              style={{ border: "1px dashed var(--outline)", color: "var(--on-surface-variant)" }}
            >
              <span className="material-symbols-rounded text-lg">content_copy</span>
              {t("copyPreviousDay")}
            </button>
          )}
        </div>
      </div>

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
          date: format(subDays(date, 1), "MMM d"),
        })}
        confirmLabel={t("copyPreviousDay")}
        confirming={copyMealsMutation.isPending}
        onConfirm={() => copyMealsMutation.mutate(previousDayMeals)}
        onCancel={() => setCopyingPreviousDay(false)}
      />
    </div>
  );
}
