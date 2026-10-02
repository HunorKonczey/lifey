"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Button, Drawer, NumberField } from "@/components/ds";
import type { SettingsResponse } from "../types";

export type GoalKey = "dailyCalorieGoal" | "dailyProteinGoal" | "dailyCarbsGoal" | "dailyFatGoal" | "dailyWaterGoalLiters" | "dailyStepGoal";

export interface GoalDef {
  key: GoalKey;
  label: string;
  unit: string;
  color: string;
  decimals: number;
}

/** "Napi célok" editor (W6.10): one number field per target; a field left at 0 clears that goal. */
export function GoalsDrawer({ goals, settings, saving, onSave, onClose }: {
  goals: GoalDef[];
  settings: SettingsResponse;
  saving: boolean;
  onSave: (values: Partial<Record<GoalKey, number | null>>) => void;
  onClose: () => void;
}) {
  const t = useTranslations("settings");
  const common = useTranslations("common");
  const initial = Object.fromEntries(goals.map((g) => [g.key, settings[g.key] ?? 0])) as Record<GoalKey, number>;
  const [values, setValues] = useState(initial);
  const dirty = goals.some((g) => values[g.key] !== initial[g.key]);

  return (
    <Drawer
      open
      onClose={onClose}
      width={480}
      title={t("editGoals")}
      isDirty={dirty}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>{common("cancel")}</Button>
          <Button
            disabled={saving}
            onClick={() => onSave(Object.fromEntries(goals.map((g) => [g.key, values[g.key] > 0 ? values[g.key] : null])))}
          >
            {saving ? t("saving") : t("saveChanges")}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-5">
        <p className="type-body-s" style={{ color: "var(--text-2)" }}>{t("goalsHint")}</p>
        {goals.map((g) => (
          <NumberField
            key={g.key}
            label={g.label}
            unit={g.unit || undefined}
            min={0}
            step={g.decimals ? 0.1 : g.key === "dailyStepGoal" ? 500 : 10}
            maxDecimals={g.decimals}
            value={values[g.key]}
            onChange={(v) => setValues((s) => ({ ...s, [g.key]: v }))}
          />
        ))}
      </div>
    </Drawer>
  );
}
