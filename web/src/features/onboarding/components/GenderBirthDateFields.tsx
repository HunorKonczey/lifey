"use client";

import { subYears } from "date-fns";
import type { FieldErrors, UseFormRegister, UseFormSetValue, UseFormWatch } from "react-hook-form";
import { useTranslations } from "next-intl";
import { DatePicker } from "@/components/ui/DatePicker";
import { OptionCard } from "./OptionCard";
import type { OnboardingFormValues } from "../schemas";
import type { Gender } from "../types";

// Mirrors the backend's BirthDateValidator / the onboarding schema's
// isValidBirthDate: age must be between 13 and 120.
const MIN_BIRTH_DATE = subYears(new Date(), 120);
const MAX_BIRTH_DATE = subYears(new Date(), 13);

const GENDERS: { value: Gender; icon: string }[] = [
  { value: "MALE", icon: "man" },
  { value: "FEMALE", icon: "woman" },
  { value: "UNSPECIFIED", icon: "person" },
];

interface Props {
  register: UseFormRegister<OnboardingFormValues>;
  watch: UseFormWatch<OnboardingFormValues>;
  setValue: UseFormSetValue<OnboardingFormValues>;
  errors: FieldErrors<OnboardingFormValues>;
}

export function GenderBirthDateFields({ watch, setValue, errors }: Props) {
  const t = useTranslations("onboarding");
  const gender = watch("gender");

  return (
    <div className="flex flex-col gap-5">
      <div className="flex flex-col gap-2">
        <label className="text-sm font-semibold">{t("gender")}</label>
        <div className="grid grid-cols-3 gap-3">
          {GENDERS.map((g) => (
            <OptionCard
              key={g.value}
              icon={g.icon}
              label={t(`gender_${g.value}`)}
              active={gender === g.value}
              onClick={() => setValue("gender", g.value, { shouldValidate: true })}
            />
          ))}
        </div>
        {errors.gender && (
          <p className="text-xs" style={{ color: "var(--error)" }}>{t("required")}</p>
        )}
      </div>

      <div className="flex flex-col gap-1 max-w-xs">
        <label className="text-sm font-semibold">{t("birthDate")}</label>
        <DatePicker
          value={watch("birthDate") ?? ""}
          onChange={(v) => setValue("birthDate", v, { shouldValidate: true })}
          min={MIN_BIRTH_DATE}
          max={MAX_BIRTH_DATE}
          hasError={!!errors.birthDate}
        />
        {errors.birthDate && (
          <p className="text-xs" style={{ color: "var(--error)" }}>{t(errors.birthDate.message ?? "invalidBirthDate")}</p>
        )}
      </div>
    </div>
  );
}
