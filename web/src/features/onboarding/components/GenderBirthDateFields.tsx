"use client";

import { format } from "date-fns";
import type { FieldErrors, UseFormRegister, UseFormSetValue, UseFormWatch } from "react-hook-form";
import { useTranslations } from "next-intl";
import { DateFields } from "@/components/ds/date/DateFields";
import { OptionCard } from "./OptionCard";
import type { OnboardingFormValues } from "../schemas";
import type { Gender } from "../types";

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
  const birthValue = watch("birthDate");
  // Typed year / month / day (W6.5): the form keeps the ISO string, the fields want a Date (or null while incomplete).
  const parsed = birthValue ? new Date(birthValue) : null;
  const birthDate = parsed && !Number.isNaN(parsed.getTime()) ? parsed : null;

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

      <DateFields
        label={t("birthDate")}
        value={birthDate}
        onChange={(d) => setValue("birthDate", d ? format(d, "yyyy-MM-dd") : "", { shouldValidate: true })}
        error={errors.birthDate ? t(errors.birthDate.message ?? "invalidBirthDate") : undefined}
        className="max-w-xs"
      />
    </div>
  );
}
