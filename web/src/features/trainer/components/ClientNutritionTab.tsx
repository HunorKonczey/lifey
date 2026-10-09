"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { format } from "date-fns";
import { Button, Card, Icon, MetricBar, TintedChip } from "@/components/ds";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";
import { MealCard, mealCarbs, mealFat, mealKcal, mealProtein } from "@/features/nutrition/components/MealCard";
import type { MealResponse, MealType } from "@/features/nutrition/types";
import { queryKeys } from "@/lib/api/queryKeys";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { useFormat } from "@/lib/format/useFormat";
import { trainerGoalsChip, type TrainerGoalsChip } from "@/features/settings/goalsSource";
import { trainerApi } from "../api";
import { MealCommentEditor } from "./MealCommentEditor";
import { NutritionGoalsDrawer } from "./NutritionGoalsDrawer";

/** The message each attribution chip uses (admin.clientDetail). */
const GOALS_CHIP_KEY = {
  byYou: "goalsSetByYou",
  byOtherTrainer: "goalsSetByOtherTrainer",
  byClient: "goalsSetByClient",
} as const satisfies Record<TrainerGoalsChip["key"], string>;

interface ClientNutritionTabProps {
  clientId: number;
}

/**
 * The client's day of meals (W7-C), read-only: the W2 meal cards with no add / edit / delete anywhere, grouped by meal
 * type, beside the day's summary against the client's goals. The day is the top bar's date stepper. "Célok
 * szerkesztése" opens the existing goals editor in a drawer — the one thing a trainer may change on this tab.
 */
export function ClientNutritionTab({ clientId }: ClientNutritionTabProps) {
  const t = useTranslations("admin.clientDetail");
  const n = useTranslations("nutrition");
  const d = useTranslations("dashboard");
  const fmt = useFormat();
  const { date } = useDateStore();
  const dateStr = format(date, "yyyy-MM-dd");
  const [editingGoals, setEditingGoals] = useState(false);

  const groups: { type: MealType; label: string; icon: string }[] = [
    { type: "BREAKFAST", label: n("breakfast"), icon: "bakery_dining" },
    { type: "LUNCH", label: n("lunch"), icon: "lunch_dining" },
    { type: "DINNER", label: n("dinner"), icon: "dinner_dining" },
    { type: "SNACK", label: n("snack"), icon: "icecream" },
  ];

  const mealsQ = useQuery({
    queryKey: queryKeys.trainerClientData.meals(clientId, dateStr),
    queryFn: () => trainerApi.clientMeals(clientId, dateStr, dateStr),
  });
  const goalsSourceQ = useQuery({
    queryKey: queryKeys.trainerClientData.nutritionGoalsSource(clientId),
    queryFn: () => trainerApi.clientNutritionGoalsSource(clientId),
  });
  const goalsQ = useQuery({
    queryKey: queryKeys.trainerClientData.nutritionGoals(clientId),
    queryFn: () => trainerApi.clientNutritionGoals(clientId),
  });

  if (mealsQ.isLoading || goalsQ.isLoading) {
    return (
      <div className="flex flex-col xl:flex-row gap-6">
        <div className="flex-1 flex flex-col gap-3">{[0, 1, 2, 3].map((i) => <Skeleton key={i} variant="card" className="h-24" />)}</div>
        <Skeleton variant="card" className="w-full xl:w-[320px] h-80" />
      </div>
    );
  }
  if (mealsQ.isError || goalsQ.isError) return <ErrorState inline onRetry={() => { mealsQ.refetch(); goalsQ.refetch(); }} />;

  const meals: MealResponse[] = mealsQ.data ?? [];
  const goals = goalsQ.data;
  const goalsChip = trainerGoalsChip(goalsSourceQ.data);
  const sum = (pick: (m: MealResponse) => number) => meals.reduce((s, m) => s + pick(m), 0);
  const kcal = sum(mealKcal);
  const macros = [
    { label: d("protein"), value: sum(mealProtein), goal: goals?.dailyProteinGoal ?? null, color: "var(--m-protein)" },
    { label: d("carbs"), value: sum(mealCarbs), goal: goals?.dailyCarbsGoal ?? null, color: "var(--m-carbs)" },
    { label: d("fat"), value: sum(mealFat), goal: goals?.dailyFatGoal ?? null, color: "var(--m-fat)" },
  ];
  const calGoal = goals?.dailyCalorieGoal ?? null;

  return (
    <div className="flex flex-col xl:flex-row gap-6 items-start">
      <div className="flex-1 min-w-0 w-full flex flex-col gap-6 order-2 xl:order-1">
        {groups.map(({ type, label, icon }) => {
          const groupMeals = meals.filter((m) => m.mealType === type);
          const groupKcal = groupMeals.reduce((s, m) => s + mealKcal(m), 0);
          return (
            <section key={type} className="flex flex-col gap-2" aria-label={label}>
              <div className="flex items-center gap-2 px-1">
                <Icon name={icon} size={22} fill={1} color="var(--m-kcal)" />
                <h3 style={{ fontSize: 15, fontWeight: 800 }}>{label}</h3>
                {groupKcal > 0 && (
                  <span className="ml-auto num type-body-s" style={{ color: "var(--m-kcal)", fontWeight: 700 }}>
                    {fmt.number(groupKcal, 0)} kcal
                  </span>
                )}
              </div>
              {groupMeals.length > 0 ? (
                groupMeals.map((meal) => (
                  <MealCard key={meal.id} meal={meal} commentSlot={<MealCommentEditor clientId={clientId} meal={meal} date={dateStr} />} />
                ))
              ) : (
                <div className="py-3 text-center type-body-s" style={{ borderRadius: "var(--r-card)", boxShadow: "inset 0 0 0 1px var(--hairline)", color: "var(--text-3)" }}>
                  {t("noLoggedMeal")}
                </div>
              )}
            </section>
          );
        })}
      </div>

      <Card variant="card" className="w-full xl:w-[320px] xl:shrink-0 order-1 xl:order-2 xl:sticky xl:top-24 flex flex-col gap-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h3 style={{ fontSize: 18, fontWeight: 800 }}>{n("dailySummary")}</h3>
          <Button variant="secondary" className="whitespace-nowrap" onClick={() => setEditingGoals(true)}>
            <Icon name="edit" size={18} />
            {t("goalsEdit")}
          </Button>
        </div>
        {goalsChip && (
          <div data-testid="goals-source-chip">
            <TintedChip icon="person" color="var(--role)" label={t(GOALS_CHIP_KEY[goalsChip.key], { date: fmt.shortDate(new Date(goalsChip.at)) })} />
          </div>
        )}
        <div>
          <div className="flex items-baseline gap-2">
            <span className="num" style={{ fontSize: 32, fontWeight: 800, letterSpacing: "-0.02em" }}>{fmt.number(kcal, 0)}</span>
            <span className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 600 }}>
              {calGoal != null ? `/ ${fmt.number(calGoal, 0)} kcal` : "kcal"}
            </span>
          </div>
          {calGoal != null && <div className="mt-2"><MetricBar progress={kcal / calGoal} color={kcal > calGoal ? "var(--heart)" : "var(--m-kcal)"} /></div>}
        </div>
        {macros.map((m) => (
          <div key={m.label}>
            <div className="flex justify-between type-body-s mb-1.5">
              <span style={{ color: m.color, fontWeight: 700 }}>{m.label}</span>
              <span className="num" style={{ color: "var(--text-2)" }}>{fmt.number(m.value, 0)}{m.goal != null ? ` / ${fmt.number(m.goal, 0)}` : ""} g</span>
            </div>
            {m.goal != null && <MetricBar progress={m.value / m.goal} color={m.color} />}
          </div>
        ))}
        <dl className="flex flex-col gap-1.5 pt-3 type-body-s" style={{ borderTop: "1px solid var(--hairline)" }}>
          <div className="flex justify-between"><dt style={{ color: "var(--text-2)" }}>{n("mealsCount")}</dt><dd className="num" style={{ fontWeight: 700 }}>{meals.length}</dd></div>
          <div className="flex justify-between"><dt style={{ color: "var(--text-2)" }}>{n("items")}</dt><dd className="num" style={{ fontWeight: 700 }}>{meals.reduce((s, m) => s + m.entries.length, 0)}</dd></div>
        </dl>
      </Card>

      {editingGoals && <NutritionGoalsDrawer clientId={clientId} goals={goals} onClose={() => setEditingGoals(false)} />}
    </div>
  );
}
