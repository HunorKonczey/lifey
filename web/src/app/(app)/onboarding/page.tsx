"use client";

import { useEffect, useRef, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import { onboardingSchema, STEP_FIELDS, type OnboardingFormValues } from "@/features/onboarding/schemas";
import { userDetailsApi } from "@/features/onboarding/api";
import { GenderBirthDateFields } from "@/features/onboarding/components/GenderBirthDateFields";
import { BodyFields } from "@/features/onboarding/components/BodyFields";
import { LifestyleGoalFields } from "@/features/onboarding/components/LifestyleGoalFields";
import { settingsApi } from "@/features/settings/api";
import { weightApi } from "@/features/weight/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { ApiError } from "@/lib/api/client";
import type { SuggestGoalsResponse } from "@/features/onboarding/types";

const STEP_COUNT = 5; // Welcome, About you, Body, Lifestyle & goal, Suggested plan

export default function OnboardingPage() {
  const t = useTranslations("onboarding");
  const d = useTranslations("dashboard");
  const router = useRouter();
  const queryClient = useQueryClient();
  const { show } = useToast();

  const [step, setStep] = useState(0);
  const [finishing, setFinishing] = useState(false);
  const [suggestion, setSuggestion] = useState<SuggestGoalsResponse | null>(null);
  const suggestRequested = useRef(false);

  const { data: settings } = useQuery({
    queryKey: queryKeys.settings.all(),
    queryFn: settingsApi.get,
  });
  const unitSystem = settings?.unitSystem ?? "METRIC";

  const {
    register, watch, setValue, trigger, getValues,
    formState: { errors },
  } = useForm<OnboardingFormValues>({
    resolver: zodResolver(onboardingSchema),
  });

  const suggestGoalsMutation = useMutation({
    mutationFn: userDetailsApi.suggestGoals,
    onSuccess: (res) => setSuggestion(res),
    onError: () => show(t("suggestFailed"), "error"),
  });

  useEffect(() => {
    if (step !== 4 || suggestRequested.current) return;
    suggestRequested.current = true;
    const v = getValues();
    suggestGoalsMutation.mutate({
      gender: v.gender,
      birthDate: v.birthDate,
      heightCm: v.heightCm,
      weightKg: v.currentWeightKg,
      activityLevel: v.activityLevel,
      primaryGoal: v.primaryGoal,
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [step]);

  const next = async () => {
    if (step === 0) {
      setStep(1);
      return;
    }
    const fields = STEP_FIELDS[step];
    const valid = fields ? await trigger(fields) : true;
    if (valid) setStep((s) => Math.min(s + 1, STEP_COUNT - 1));
  };

  const back = () => setStep((s) => Math.max(s - 1, 0));

  const skip = () => router.push("/dashboard");

  const finish = async (applyGoals: boolean) => {
    setFinishing(true);
    try {
      const v = getValues();
      await userDetailsApi.update({
        gender: v.gender,
        birthDate: v.birthDate,
        heightCm: v.heightCm,
        activityLevel: v.activityLevel,
        primaryGoal: v.primaryGoal,
        targetWeightKg: v.targetWeightKg ?? null,
      });
      await weightApi.create({ date: format(new Date(), "yyyy-MM-dd"), weight: v.currentWeightKg });

      if (applyGoals && suggestion && settings) {
        await settingsApi.update({
          ...settings,
          dailyCalorieGoal: suggestion.calories,
          dailyProteinGoal: suggestion.proteinGrams,
          dailyCarbsGoal: suggestion.carbsGrams,
          dailyFatGoal: suggestion.fatGrams,
          dailyWaterGoalLiters: suggestion.waterLiters,
        });
      }

      queryClient.invalidateQueries({ queryKey: queryKeys.userDetails.all() });
      queryClient.invalidateQueries({ queryKey: queryKeys.weights.all() });
      queryClient.invalidateQueries({ queryKey: queryKeys.settings.all() });
      show(t("onboardingComplete"), "success");
      router.push("/dashboard");
    } catch (err) {
      const message = err instanceof ApiError ? err.message : t("saveFailed");
      show(message, "error");
    } finally {
      setFinishing(false);
    }
  };

  return (
    <div className="flex flex-col items-center py-6">
      <div className="w-full max-w-2xl rounded-[var(--r-lg)] p-8" style={{ background: "var(--surface)" }}>
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-2">
            {Array.from({ length: STEP_COUNT }).map((_, i) => (
              <span
                key={i}
                className="rounded-full transition-colors"
                style={{
                  width: i === step ? 20 : 8,
                  height: 8,
                  background: i <= step ? "var(--primary)" : "var(--surface-highest)",
                }}
              />
            ))}
          </div>
          <button onClick={skip} className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>
            {t("skip")}
          </button>
        </div>

        {step === 0 && (
          <div className="flex flex-col items-center text-center gap-3 py-8">
            <span className="material-symbols-rounded text-5xl" style={{ color: "var(--primary)", fontVariationSettings: "'FILL' 1" }}>
              eco
            </span>
            <h1 className="text-2xl font-bold">{t("welcomeTitle")}</h1>
            <p className="text-sm max-w-sm" style={{ color: "var(--on-surface-variant)" }}>{t("welcomeBody")}</p>
          </div>
        )}

        {step === 1 && (
          <div className="flex flex-col gap-5">
            <h2 className="text-lg font-bold">{t("aboutYouTitle")}</h2>
            <GenderBirthDateFields register={register} watch={watch} setValue={setValue} errors={errors} />
          </div>
        )}

        {step === 2 && (
          <div className="flex flex-col gap-5">
            <h2 className="text-lg font-bold">{t("bodyTitle")}</h2>
            <BodyFields register={register} setValue={setValue} errors={errors} unitSystem={unitSystem} />
          </div>
        )}

        {step === 3 && (
          <div className="flex flex-col gap-5">
            <h2 className="text-lg font-bold">{t("lifestyleTitle")}</h2>
            <LifestyleGoalFields register={register} watch={watch} setValue={setValue} errors={errors} unitSystem={unitSystem} />
          </div>
        )}

        {step === 4 && (
          <div className="flex flex-col gap-5">
            <h2 className="text-lg font-bold">{t("suggestedTitle")}</h2>
            {suggestGoalsMutation.isPending || !suggestion ? (
              <p className="text-sm py-8 text-center" style={{ color: "var(--on-surface-variant)" }}>{t("calculating")}</p>
            ) : (
              <>
                <p className="text-xs" style={{ color: "var(--on-surface-variant)" }}>
                  {t("suggestedFrom", { bmr: suggestion.bmr, tdee: suggestion.tdee })}
                </p>
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                  {[
                    { label: d("calories"), value: suggestion.calories, unit: "kcal", color: "var(--metric-kcal)" },
                    { label: d("protein"), value: suggestion.proteinGrams, unit: "g", color: "var(--metric-protein)" },
                    { label: d("carbs"), value: suggestion.carbsGrams, unit: "g", color: "var(--metric-carbs)" },
                    { label: d("fat"), value: suggestion.fatGrams, unit: "g", color: "var(--metric-fat)" },
                    { label: d("water"), value: suggestion.waterLiters, unit: "L", color: "var(--metric-water)" },
                  ].map((m) => (
                    <div key={m.label} className="flex flex-col gap-1 p-3 rounded-[var(--r-card)]" style={{ background: "var(--surface-container)" }}>
                      <span className="text-xs font-semibold" style={{ color: m.color }}>{m.label}</span>
                      <span className="text-xl font-extrabold tabular">{m.value} <span className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{m.unit}</span></span>
                    </div>
                  ))}
                </div>
                <p className="text-xs" style={{ color: "var(--muted)" }}>{t("changeLater")}</p>
              </>
            )}
          </div>
        )}

        <div className="flex items-center justify-between mt-8">
          <button
            onClick={back}
            disabled={step === 0}
            className="h-10 px-5 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-0"
            style={{ background: "var(--surface-container)", color: "var(--on-surface)" }}
          >
            {t("back")}
          </button>

          {step < 4 ? (
            <button
              onClick={next}
              className="h-10 px-6 rounded-[var(--r-input)] font-semibold text-sm"
              style={{ background: "var(--primary)", color: "#1E1F18" }}
            >
              {step === 0 ? t("getStarted") : t("next")}
            </button>
          ) : (
            <div className="flex gap-3">
              <button
                onClick={() => finish(false)}
                disabled={finishing}
                className="h-10 px-5 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
                style={{ background: "var(--surface-container)", color: "var(--on-surface)" }}
              >
                {t("notNow")}
              </button>
              <button
                onClick={() => finish(true)}
                disabled={finishing || !suggestion}
                className="h-10 px-6 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
                style={{ background: "var(--primary)", color: "#1E1F18" }}
              >
                {finishing ? t("saving") : t("applyGoals")}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
