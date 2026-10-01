"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Button } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { GoalsDrawer, type GoalDef } from "../GoalsDrawer";
import { SettingsSection } from "../SettingsSection";
import { useSettings } from "../../useSettings";

/** The six targets with their labels, units and metric colours — shared by the section and the phone list. */
export function useGoalDefs(): GoalDef[] {
  const d = useTranslations("dashboard");
  return [
    { key: "dailyCalorieGoal", label: d("calories"), unit: "kcal", color: "var(--metric-kcal)", decimals: 0 },
    { key: "dailyProteinGoal", label: d("protein"), unit: "g", color: "var(--metric-protein)", decimals: 0 },
    { key: "dailyCarbsGoal", label: d("carbs"), unit: "g", color: "var(--metric-carbs)", decimals: 0 },
    { key: "dailyFatGoal", label: d("fat"), unit: "g", color: "var(--metric-fat)", decimals: 0 },
    { key: "dailyWaterGoalLiters", label: d("water"), unit: "L", color: "var(--metric-water)", decimals: 1 },
    { key: "dailyStepGoal", label: d("steps"), unit: "", color: "var(--metric-steps)", decimals: 0 },
  ];
}

/** Daily goals (W6-G): the targets as tiles in their metric colours, "Szerkesztés" opens the editor drawer. */
export function GoalsSection() {
  const t = useTranslations("settings");
  const fmt = useFormat();
  const goalDefs = useGoalDefs();
  const { settings, save, saving } = useSettings();
  const [editing, setEditing] = useState(false);
  if (!settings) return null;

  const goals = goalDefs;

  return (
    <SettingsSection
      id="settings-goals"
      title={t("dailyGoals")}
      action={<Button variant="secondary" onClick={() => setEditing(true)}>{t("edit")}</Button>}
    >
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
        {goals.map((g) => {
          const value = settings[g.key];
          return (
            <div key={g.key} className="flex flex-col gap-1 p-4" style={{ borderRadius: "var(--r-card)", background: "var(--nested)" }}>
              <span className="type-body-s" style={{ color: g.color, fontWeight: 700 }}>{g.label}</span>
              <span className="num" style={{ fontSize: 22, fontWeight: 800 }}>
                {value == null ? "—" : fmt.number(value, g.decimals)}
                {value != null && g.unit && <span className="type-body-s" style={{ color: "var(--text-2)" }}> {g.unit}</span>}
              </span>
            </div>
          );
        })}
      </div>
      {editing && (
        <GoalsDrawer
          goals={goals}
          settings={settings}
          saving={saving}
          onSave={(values) => save(values, { onSuccess: () => setEditing(false) })}
          onClose={() => setEditing(false)}
        />
      )}
    </SettingsSection>
  );
}
