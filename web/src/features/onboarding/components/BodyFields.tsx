"use client";

import { useState } from "react";
import type { FieldErrors, UseFormRegister, UseFormSetValue } from "react-hook-form";
import { useTranslations } from "next-intl";
import { lbToKg } from "@/lib/utils/units";
import { HeightField } from "./HeightField";
import type { UnitSystem } from "@/features/settings/types";
import type { OnboardingFormValues } from "../schemas";

interface Props {
  register: UseFormRegister<OnboardingFormValues>;
  setValue: UseFormSetValue<OnboardingFormValues>;
  errors: FieldErrors<OnboardingFormValues>;
  unitSystem: UnitSystem;
}

const inputStyle = { background: "var(--surface-container)", border: "1px solid var(--outline)" };

/** Onboarding-only: height + the current weight that seeds the first
 *  weight_entries row. Settings > Profile reuses HeightField alone, since
 *  weight there is edited through the dedicated Weight page instead. */
export function BodyFields({ register, setValue, errors, unitSystem }: Props) {
  const t = useTranslations("onboarding");
  const isImperial = unitSystem === "IMPERIAL";
  const [lb, setLb] = useState("");

  const applyWeightImperial = (lbVal: string) => {
    setLb(lbVal);
    const v = Number(lbVal);
    if (lbVal !== "" && !Number.isNaN(v)) {
      setValue("currentWeightKg", lbToKg(v), { shouldValidate: true });
    }
  };

  return (
    <div className="flex flex-col gap-5">
      <HeightField register={register} setValue={setValue} errors={errors} unitSystem={unitSystem} />

      <div className="flex flex-col gap-1 max-w-xs">
        <label className="text-sm font-semibold">{t("currentWeight")}</label>
        {isImperial ? (
          <div className="flex items-center gap-1 px-3 h-11 rounded-[var(--r-input)] w-40" style={inputStyle} data-ring-frame>
            <input
              type="number" step="0.1" value={lb}
              onChange={(e) => applyWeightImperial(e.target.value)}
              className="flex-1 min-w-0 bg-transparent outline-none text-sm tabular"
            />
            <span className="text-sm" style={{ color: "var(--on-surface-variant)" }}>lb</span>
          </div>
        ) : (
          <div className="flex items-center gap-1 px-3 h-11 rounded-[var(--r-input)] w-40" style={inputStyle} data-ring-frame>
            <input
              {...register("currentWeightKg", { valueAsNumber: true })}
              type="number" step="0.1"
              className="flex-1 min-w-0 bg-transparent outline-none text-sm tabular"
            />
            <span className="text-sm" style={{ color: "var(--on-surface-variant)" }}>kg</span>
          </div>
        )}
        {errors.currentWeightKg && (
          <p className="text-xs" style={{ color: "var(--error)" }}>{t(errors.currentWeightKg.message ?? "weightRange")}</p>
        )}
      </div>
    </div>
  );
}
