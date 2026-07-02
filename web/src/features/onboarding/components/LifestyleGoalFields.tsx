"use client";

import { useState } from "react";
import type { FieldErrors, UseFormRegister, UseFormSetValue, UseFormWatch } from "react-hook-form";
import { useTranslations } from "next-intl";
import { OptionCard } from "./OptionCard";
import { lbToKg } from "@/lib/utils/units";
import type { UnitSystem } from "@/features/settings/types";
import type { OnboardingFormValues } from "../schemas";
import type { ActivityLevel, PrimaryGoal } from "../types";

const ACTIVITY_LEVELS: { value: ActivityLevel; icon: string }[] = [
  { value: "SEDENTARY", icon: "weekend" },
  { value: "LIGHT", icon: "directions_walk" },
  { value: "MODERATE", icon: "directions_run" },
  { value: "ACTIVE", icon: "fitness_center" },
  { value: "VERY_ACTIVE", icon: "bolt" },
];

const GOALS: { value: PrimaryGoal; icon: string }[] = [
  { value: "LOSE_WEIGHT", icon: "trending_down" },
  { value: "MAINTAIN", icon: "trending_flat" },
  { value: "GAIN_MUSCLE", icon: "trending_up" },
];

interface Props {
  register: UseFormRegister<OnboardingFormValues>;
  watch: UseFormWatch<OnboardingFormValues>;
  setValue: UseFormSetValue<OnboardingFormValues>;
  errors: FieldErrors<OnboardingFormValues>;
  unitSystem: UnitSystem;
}

export function LifestyleGoalFields({ register, watch, setValue, errors, unitSystem }: Props) {
  const t = useTranslations("onboarding");
  const activityLevel = watch("activityLevel");
  const primaryGoal = watch("primaryGoal");
  const isImperial = unitSystem === "IMPERIAL";
  const [targetLb, setTargetLb] = useState("");

  const applyTargetImperial = (lbVal: string) => {
    setTargetLb(lbVal);
    const v = Number(lbVal);
    if (lbVal !== "" && !Number.isNaN(v)) {
      setValue("targetWeightKg", lbToKg(v), { shouldValidate: true });
    } else if (lbVal === "") {
      setValue("targetWeightKg", undefined, { shouldValidate: true });
    }
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-2">
        <label className="text-sm font-semibold">{t("activityLevel")}</label>
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {ACTIVITY_LEVELS.map((a) => (
            <OptionCard
              key={a.value}
              icon={a.icon}
              label={t(`activity_${a.value}`)}
              description={t(`activityDescription_${a.value}`)}
              active={activityLevel === a.value}
              onClick={() => setValue("activityLevel", a.value, { shouldValidate: true })}
            />
          ))}
        </div>
        {errors.activityLevel && (
          <p className="text-xs" style={{ color: "var(--error)" }}>{t("required")}</p>
        )}
      </div>

      <div className="flex flex-col gap-2">
        <label className="text-sm font-semibold">{t("primaryGoal")}</label>
        <div className="grid grid-cols-3 gap-3">
          {GOALS.map((g) => (
            <OptionCard
              key={g.value}
              icon={g.icon}
              label={t(`goal_${g.value}`)}
              active={primaryGoal === g.value}
              onClick={() => setValue("primaryGoal", g.value, { shouldValidate: true })}
            />
          ))}
        </div>
        {errors.primaryGoal && (
          <p className="text-xs" style={{ color: "var(--error)" }}>{t("required")}</p>
        )}
      </div>

      {primaryGoal && primaryGoal !== "MAINTAIN" && (
        <div className="flex flex-col gap-1 max-w-xs">
          <label className="text-sm font-semibold">{t("targetWeightOptional")}</label>
          <div className="flex items-center gap-1 px-3 h-11 rounded-[var(--r-input)] w-40"
            style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
            data-ring-frame>
            {isImperial ? (
              <input
                type="number" step="0.1" value={targetLb}
                onChange={(e) => applyTargetImperial(e.target.value)}
                className="flex-1 min-w-0 bg-transparent outline-none text-sm tabular"
              />
            ) : (
              <input
                {...register("targetWeightKg", { valueAsNumber: true })}
                type="number" step="0.1"
                className="flex-1 min-w-0 bg-transparent outline-none text-sm tabular"
              />
            )}
            <span className="text-sm" style={{ color: "var(--on-surface-variant)" }}>{isImperial ? "lb" : "kg"}</span>
          </div>
          {errors.targetWeightKg && (
            <p className="text-xs" style={{ color: "var(--error)" }}>{t(errors.targetWeightKg.message ?? "weightRange")}</p>
          )}
        </div>
      )}
    </div>
  );
}
