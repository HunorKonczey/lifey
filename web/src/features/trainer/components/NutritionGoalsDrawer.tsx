"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Button, Drawer, TextField } from "@/components/ds";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { trainerApi } from "../api";
import { goalToInput, isValidGoalInput, parseGoalInput } from "../nutritionGoalsEditor";
import type { ClientNutritionGoalsResponse } from "../types";

type Draft = { calorie: string; protein: string; carbs: string; fat: string };

/**
 * "Célok szerkesztése" (W7.10): the trainer's nutrition-goals editor for one client, now in the DS drawer instead of
 * inside the summary panel. The logic is the existing one (`nutritionGoalsEditor`): four fields, blank clears a goal,
 * anything that is not a whole number is flagged and blocks the save.
 */
export function NutritionGoalsDrawer({ clientId, goals, onClose }: { clientId: number; goals: ClientNutritionGoalsResponse | undefined; onClose: () => void }) {
  const t = useTranslations("admin.clientDetail");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const initial: Draft = {
    calorie: goalToInput(goals?.dailyCalorieGoal),
    protein: goalToInput(goals?.dailyProteinGoal),
    carbs: goalToInput(goals?.dailyCarbsGoal),
    fat: goalToInput(goals?.dailyFatGoal),
  };
  const [draft, setDraft] = useState<Draft>(initial);
  const dirty = (Object.keys(initial) as (keyof Draft)[]).some((k) => draft[k] !== initial[k]);
  const canSave = (Object.values(draft) as string[]).every(isValidGoalInput);

  const save = useMutation({
    mutationFn: (request: ClientNutritionGoalsResponse) => trainerApi.updateClientNutritionGoals(clientId, request),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerClientData.nutritionGoals(clientId) });
      show(t("goalsUpdated"));
      onClose();
    },
    onError: () => show(t("goalsSaveFailed"), "error"),
  });

  const field = (key: keyof Draft, label: string, unit: string) => (
    <TextField
      label={label}
      inputMode="numeric"
      value={draft[key]}
      onChange={(e) => setDraft((d) => ({ ...d, [key]: e.target.value }))}
      error={isValidGoalInput(draft[key]) ? undefined : t("goalsInvalid")}
      hint={unit}
    />
  );

  return (
    <Drawer
      open
      onClose={onClose}
      width={480}
      title={t("goalsEdit")}
      isDirty={dirty}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>{common("cancel")}</Button>
          <Button
            disabled={!canSave || save.isPending}
            onClick={() =>
              save.mutate({
                dailyCalorieGoal: parseGoalInput(draft.calorie),
                dailyProteinGoal: parseGoalInput(draft.protein),
                dailyCarbsGoal: parseGoalInput(draft.carbs),
                dailyFatGoal: parseGoalInput(draft.fat),
              })
            }
          >
            {save.isPending ? common("saving") : t("goalsSave")}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-5">
        <p className="type-body-s" style={{ color: "var(--text-2)" }}>{t("goalsDrawerHint")}</p>
        {field("calorie", t("goalsCalorieLabel"), "kcal")}
        {field("protein", t("goalsProteinLabel"), "g")}
        {field("carbs", t("goalsCarbsLabel"), "g")}
        {field("fat", t("goalsFatLabel"), "g")}
      </div>
    </Drawer>
  );
}
