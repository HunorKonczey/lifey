"use client";

import { useState } from "react";
import type { FieldErrors, UseFormRegister, UseFormSetValue } from "react-hook-form";
import { useTranslations } from "next-intl";
import { feetInchesToCm } from "@/lib/utils/units";
import type { UnitSystem } from "@/features/settings/types";
import type { OnboardingFormValues } from "../schemas";

interface Props {
  register: UseFormRegister<OnboardingFormValues>;
  setValue: UseFormSetValue<OnboardingFormValues>;
  errors: FieldErrors<OnboardingFormValues>;
  unitSystem: UnitSystem;
}

const inputStyle = { background: "var(--surface-container)", border: "1px solid var(--outline)" };

/** Height input, unit-aware (cm vs ft/in). Shared between the onboarding
 *  wizard's Body step and Settings > Profile. Settings seeds the form's
 *  (unused/unsubmitted) currentWeightKg from the user's latest weight entry
 *  purely so the shared OnboardingFormValues schema validates — see the
 *  Settings page comment for why. */
export function HeightField({ register, setValue, errors, unitSystem }: Props) {
  const t = useTranslations("onboarding");
  const isImperial = unitSystem === "IMPERIAL";

  const [feet, setFeet] = useState("");
  const [inches, setInches] = useState("");

  const applyHeightImperial = (feetVal: string, inchesVal: string) => {
    setFeet(feetVal);
    setInches(inchesVal);
    const f = Number(feetVal);
    const i = inchesVal === "" ? 0 : Number(inchesVal);
    if (feetVal !== "" && !Number.isNaN(f) && !Number.isNaN(i)) {
      setValue("heightCm", feetInchesToCm(f, i), { shouldValidate: true });
    }
  };

  return (
    <div className="flex flex-col gap-1 max-w-xs">
      <label className="text-sm font-semibold">{t("height")}</label>
      {isImperial ? (
        <div className="flex gap-2">
          <div className="flex items-center gap-1 px-3 h-11 rounded-[var(--r-input)]" style={inputStyle} data-ring-frame>
            <input
              type="number" min={0} placeholder="5" value={feet}
              onChange={(e) => applyHeightImperial(e.target.value, inches)}
              className="w-12 min-w-0 bg-transparent outline-none text-sm tabular"
            />
            <span className="text-sm" style={{ color: "var(--on-surface-variant)" }}>{t("feet")}</span>
          </div>
          <div className="flex items-center gap-1 px-3 h-11 rounded-[var(--r-input)]" style={inputStyle} data-ring-frame>
            <input
              type="number" min={0} max={11} placeholder="10" value={inches}
              onChange={(e) => applyHeightImperial(feet, e.target.value)}
              className="w-12 min-w-0 bg-transparent outline-none text-sm tabular"
            />
            <span className="text-sm" style={{ color: "var(--on-surface-variant)" }}>{t("inches")}</span>
          </div>
        </div>
      ) : (
        <div className="flex items-center gap-1 px-3 h-11 rounded-[var(--r-input)] w-40" style={inputStyle} data-ring-frame>
          <input
            {...register("heightCm", { valueAsNumber: true })}
            type="number" step="0.1"
            className="flex-1 min-w-0 bg-transparent outline-none text-sm tabular"
          />
          <span className="text-sm" style={{ color: "var(--on-surface-variant)" }}>cm</span>
        </div>
      )}
      {errors.heightCm && (
        <p className="text-xs" style={{ color: "var(--error)" }}>{t(errors.heightCm.message ?? "heightRange")}</p>
      )}
    </div>
  );
}
