"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { format, addDays, subDays } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { MealCard, mealKcal, mealProtein, mealCarbs, mealFat } from "@/features/nutrition/components/MealCard";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";
import { useLocale } from "@/lib/hooks/useLocale";
import type { MealResponse, MealType } from "@/features/nutrition/types";

const DATE_LOCALES = { en: enUS, hu } as const;

interface ClientNutritionTabProps {
  clientId: number;
}

export function ClientNutritionTab({ clientId }: ClientNutritionTabProps) {
  const t = useTranslations("admin.clientDetail");
  const n = useTranslations("nutrition");
  const d = useTranslations("dashboard");
  const common = useTranslations("common");
  const dateLocale = DATE_LOCALES[useLocale((s) => s.locale)];
  const [date, setDate] = useState(new Date());
  const dateStr = format(date, "yyyy-MM-dd");
  const isToday = dateStr === format(new Date(), "yyyy-MM-dd");

  const MEAL_GROUPS: { type: MealType; label: string; icon: string }[] = [
    { type: "BREAKFAST", label: n("breakfast"), icon: "bakery_dining" },
    { type: "LUNCH", label: n("lunch"), icon: "lunch_dining" },
    { type: "DINNER", label: n("dinner"), icon: "dinner_dining" },
    { type: "SNACK", label: n("snack"), icon: "icecream" },
  ];

  const mealsQ = useQuery({
    queryKey: queryKeys.trainerClientData.meals(clientId, dateStr),
    queryFn: () => trainerApi.clientMeals(clientId, dateStr, dateStr),
  });
  const goalsQ = useQuery({
    queryKey: queryKeys.trainerClientData.nutritionGoals(clientId),
    queryFn: () => trainerApi.clientNutritionGoals(clientId),
  });

  if (mealsQ.isLoading || goalsQ.isLoading) {
    return (
      <div className="flex gap-6">
        <div className="flex-1 flex flex-col gap-3">
          {[0, 1, 2, 3].map((i) => <Skeleton key={i} variant="card" className="h-24" />)}
        </div>
        <Skeleton variant="card" className="w-[300px] h-80" />
      </div>
    );
  }

  if (mealsQ.isError || goalsQ.isError) {
    return <ErrorState inline onRetry={() => { mealsQ.refetch(); goalsQ.refetch(); }} />;
  }

  const meals: MealResponse[] = mealsQ.data ?? [];
  const goals = goalsQ.data;

  const totalKcal = meals.reduce((s, m) => s + mealKcal(m), 0);
  const totalProtein = meals.reduce((s, m) => s + mealProtein(m), 0);
  const totalCarbs = meals.reduce((s, m) => s + mealCarbs(m), 0);
  const totalFat = meals.reduce((s, m) => s + mealFat(m), 0);
  const totalItems = meals.reduce((s, m) => s + m.entries.length, 0);

  return (
    <div className="flex flex-col gap-3.5">
      {/* Day navigator */}
      <div className="flex items-center gap-1 rounded-[var(--r-card)] px-2 py-1.5 w-fit" style={{ background: "var(--surface)" }}>
        <button
          onClick={() => setDate((prev) => subDays(prev, 1))}
          className="p-1.5 rounded-[var(--r-sm)] transition-colors hover:bg-surface-container"
          style={{ color: "var(--on-surface-variant)" }}
          aria-label={common("previousDay")}
        >
          <span className="material-symbols-rounded text-xl">chevron_left</span>
        </button>
        <span className="text-sm font-semibold tabular px-2 min-w-[110px] text-center">
          {isToday ? common("today") : format(date, "yyyy. MMM d.", { locale: dateLocale })}
        </span>
        <button
          onClick={() => setDate((prev) => addDays(prev, 1))}
          disabled={isToday}
          className="p-1.5 rounded-[var(--r-sm)] transition-colors hover:bg-surface-container disabled:opacity-30"
          style={{ color: "var(--on-surface-variant)" }}
          aria-label={common("nextDay")}
        >
          <span className="material-symbols-rounded text-xl">chevron_right</span>
        </button>
      </div>

      <div className="flex gap-6">
        {/* Meal groups */}
        <div className="flex-1 min-w-0 flex flex-col gap-6">
          {MEAL_GROUPS.map(({ type, label, icon }) => {
            const groupMeals = meals.filter((m) => m.mealType === type);
            const groupKcal = groupMeals.reduce((s, m) => s + mealKcal(m), 0);
            return (
              <div key={type} className="flex flex-col gap-2">
                <div className="flex items-center gap-2 px-1">
                  <span className="material-symbols-rounded text-xl" style={{ color: "var(--metric-kcal)" }}>{icon}</span>
                  <span className="font-bold text-sm">{label}</span>
                  {groupKcal > 0 && (
                    <span className="ml-auto text-sm font-semibold tabular" style={{ color: "var(--metric-kcal)" }}>
                      {Math.round(groupKcal)} kcal
                    </span>
                  )}
                </div>

                {groupMeals.length > 0 ? (
                  groupMeals.map((meal) => <MealCard key={meal.id} meal={meal} />)
                ) : (
                  <div
                    className="w-full py-2.5 rounded-[var(--r-md)] text-sm font-semibold flex items-center justify-center"
                    style={{ border: "1px dashed var(--outline)", color: "var(--on-surface-variant)" }}
                  >
                    {t("noLoggedMeal")}
                  </div>
                )}
              </div>
            );
          })}
        </div>

        {/* Daily summary sticky panel */}
        <div className="w-[300px] shrink-0">
          <div className="sticky top-6 rounded-[var(--r-lg)] p-5" style={{ background: "var(--surface)" }}>
            <p className="text-sm font-bold mb-4">{n("dailySummary")}</p>

            <div className="flex items-end gap-2 mb-1">
              <span className="text-3xl font-extrabold tabular">
                {Math.round(totalKcal).toLocaleString()}
              </span>
              {goals?.dailyCalorieGoal != null && (
                <span className="text-sm font-semibold mb-1" style={{ color: "var(--on-surface-variant)" }}>
                  / {goals.dailyCalorieGoal.toLocaleString()} kcal
                </span>
              )}
            </div>
            {goals?.dailyCalorieGoal != null && (
              <div className="h-2 rounded-[var(--r-pill)] overflow-hidden mb-4" style={{ background: "var(--surface-highest)" }}>
                <div
                  className="h-full rounded-[var(--r-pill)] transition-all"
                  style={{
                    width: `${Math.min(totalKcal / goals.dailyCalorieGoal, 1) * 100}%`,
                    background: totalKcal > goals.dailyCalorieGoal ? "var(--goal-negative)" : "var(--metric-kcal)",
                  }}
                />
              </div>
            )}

            <MacroRow label={d("protein")} value={totalProtein} goal={goals?.dailyProteinGoal ?? null} color="var(--metric-protein)" />
            <MacroRow label={d("carbs")} value={totalCarbs} goal={goals?.dailyCarbsGoal ?? null} color="var(--metric-carbs)" />
            <MacroRow label={d("fat")} value={totalFat} goal={goals?.dailyFatGoal ?? null} color="var(--metric-fat)" last />

            <div className="flex justify-between pt-3 text-sm" style={{ borderTop: "1px solid var(--outline)" }}>
              <span style={{ color: "var(--on-surface-variant)" }}>{n("mealsCount")}</span>
              <span className="font-semibold tabular">{meals.length}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span style={{ color: "var(--on-surface-variant)" }}>{n("items")}</span>
              <span className="font-semibold tabular">{totalItems}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function MacroRow({
  label, value, goal, color, last = false,
}: {
  label: string;
  value: number;
  goal: number | null;
  color: string;
  last?: boolean;
}) {
  return (
    <>
      <div className="flex justify-between text-xs mb-1">
        <span style={{ color }}>{label}</span>
        <span className="tabular" style={{ color: "var(--on-surface-variant)" }}>
          {Math.round(value)}{goal != null ? ` / ${goal}g` : "g"}
        </span>
      </div>
      <div className={`h-1.5 rounded-[var(--r-pill)] overflow-hidden ${last ? "mb-3" : "mb-4"}`} style={{ background: "var(--surface-highest)" }}>
        {goal != null && (
          <div
            className="h-full rounded-[var(--r-pill)]"
            style={{ width: `${Math.min(value / goal, 1) * 100}%`, background: color }}
          />
        )}
      </div>
    </>
  );
}
