"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { format } from "date-fns";
import { mealApi } from "../api";
import { settingsApi } from "@/features/settings/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { useToast } from "@/lib/hooks/useToast";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";
import { AddMealEntryDialog } from "./AddMealEntryDialog";
import { MealCard, mealKcal, mealProtein } from "./MealCard";
import type { MealResponse, MealType } from "../types";

export function MealsView() {
  const t = useTranslations("nutrition");
  const d = useTranslations("dashboard");
  const { date } = useDateStore();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const dateStr = format(date, "yyyy-MM-dd");
  const [addingTo, setAddingTo] = useState<MealType | null>(null);
  const [editingMeal, setEditingMeal] = useState<MealResponse | null>(null);

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

  const todayMeals = (data ?? []).filter(
    (m) => format(new Date(m.dateTime), "yyyy-MM-dd") === dateStr,
  );

  const totalKcal = todayMeals.reduce((s, m) => s + mealKcal(m), 0);
  const totalProtein = todayMeals.reduce((s, m) => s + mealProtein(m), 0);
  const totalItems = todayMeals.reduce((s, m) => s + m.entries.length, 0);

  const calorieGoal = settings?.dailyCalorieGoal ?? 2000;
  const proteinGoal = settings?.dailyProteinGoal ?? 150;

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
            </div>
          );
        })}
      </div>

      {/* Daily summary sticky panel */}
      <div className="w-[300px] shrink-0">
        <div className="sticky top-6 rounded-[var(--r-lg)] p-5" style={{ background: "var(--surface)" }}>
          <p className="text-sm font-bold mb-4">{t("dailySummary")}</p>

          <div className="flex items-end gap-2 mb-1">
            <span className="text-3xl font-extrabold tabular">
              {Math.round(totalKcal).toLocaleString()}
            </span>
            <span className="text-sm font-semibold mb-1" style={{ color: "var(--on-surface-variant)" }}>
              / {calorieGoal.toLocaleString()} kcal
            </span>
          </div>
          <div className="h-2 rounded-[var(--r-pill)] overflow-hidden mb-4" style={{ background: "var(--surface-highest)" }}>
            <div
              className="h-full rounded-[var(--r-pill)] transition-all"
              style={{
                width: `${Math.min(totalKcal / calorieGoal, 1) * 100}%`,
                background: totalKcal > calorieGoal ? "var(--goal-negative)" : "var(--metric-kcal)",
              }}
            />
          </div>

          <div className="flex justify-between text-xs mb-1">
            <span style={{ color: "var(--metric-protein)" }}>{d("protein")}</span>
            <span className="tabular" style={{ color: "var(--on-surface-variant)" }}>
              {Math.round(totalProtein)} / {proteinGoal}g
            </span>
          </div>
          <div className="h-1.5 rounded-[var(--r-pill)] overflow-hidden mb-4" style={{ background: "var(--surface-highest)" }}>
            <div
              className="h-full rounded-[var(--r-pill)]"
              style={{ width: `${Math.min(totalProtein / proteinGoal, 1) * 100}%`, background: "var(--metric-protein)" }}
            />
          </div>

          <div className="flex justify-between pt-3 text-sm" style={{ borderTop: "1px solid var(--outline)" }}>
            <span style={{ color: "var(--on-surface-variant)" }}>{t("mealsCount")}</span>
            <span className="font-semibold tabular">{todayMeals.length}</span>
          </div>
          <div className="flex justify-between text-sm">
            <span style={{ color: "var(--on-surface-variant)" }}>{t("items")}</span>
            <span className="font-semibold tabular">{totalItems}</span>
          </div>
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
    </div>
  );
}
