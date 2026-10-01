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
import { Button, Icon } from "@/components/ds";
import { LifeyLogo } from "@/features/auth/components/BrandPanel";
import { SuggestedPlan } from "@/features/onboarding/components/SuggestedPlan";
import { OnboardingRail, type RailStep } from "@/features/onboarding/components/OnboardingRail";
import { useFormat } from "@/lib/format/useFormat";
import { useToast } from "@/lib/hooks/useToast";
import { ApiError } from "@/lib/api/client";
import type { SuggestGoalsResponse } from "@/features/onboarding/types";

const STEP_COUNT = 5; // Welcome, About you, Body, Lifestyle & goal, Suggested plan

export default function OnboardingPage() {
  const t = useTranslations("onboarding");
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

  // The rail reads the answers live from the form (W6-D).
  const v = watch();
  const fmt = useFormat();
  const birth = v.birthDate ? new Date(v.birthDate) : null;
  const num = (n: number | undefined) => (n == null || Number.isNaN(n) ? null : fmt.number(n));
  const railDetail = (index: number): string => {
    if (index === 0) {
      return [v.gender ? t(`gender_${v.gender}`) : null, birth && !Number.isNaN(birth.getTime()) ? fmt.mediumDate(birth) : null].filter(Boolean).join(" · ");
    }
    if (index === 1) {
      return [num(v.heightCm) && `${num(v.heightCm)} cm`, num(v.currentWeightKg) && `${num(v.currentWeightKg)} kg`].filter(Boolean).join(" · ");
    }
    if (index === 2) {
      return [v.activityLevel ? t(`activity_${v.activityLevel}`) : null, v.primaryGoal ? t(`goal_${v.primaryGoal}`).toLocaleLowerCase(fmt.locale) : null].filter(Boolean).join(" · ");
    }
    return step === 4 ? t("railNow") : "";
  };
  const railSteps: RailStep[] = [t("aboutYouTitle"), t("bodyTitle"), t("lifestyleTitle"), t("suggestedTitle")].map((title, index) => ({
    title,
    detail: index + 1 === step && index !== 3 ? (railDetail(index) || t("railNow")) : railDetail(index),
  }));
  const titles = ["", t("aboutYouTitle"), t("bodyTitle"), t("lifestyleTitle"), t("suggestedTitle")];

  if (step === 0) {
    // The intro screen: no rail yet (W6-D) — it appears with the first question.
    return (
      <div className="min-h-screen flex items-center justify-center px-6 py-10">
        <div className="flex flex-col items-center text-center gap-6 max-w-[520px]">
          <LifeyLogo size={56} />
          <h1 style={{ fontSize: 40, lineHeight: 1.1, fontWeight: 800, letterSpacing: "-0.03em" }}>{t("welcomeTitle")}</h1>
          <p style={{ fontSize: 17, lineHeight: 1.55, color: "var(--text-2)" }}>{t("welcomeBody")}</p>
          <div className="flex items-center gap-3 pt-2">
            <Button variant="ghost" size="auth" onClick={skip}>
              {t("skipLong")}
            </Button>
            <Button size="auth" onClick={next}>
              {t("getStarted")}
            </Button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen grid grid-cols-1 lg:grid-cols-[340px_minmax(0,1fr)]">
      <OnboardingRail steps={railSteps} current={step - 1} onSkip={skip} />
      <div className="flex flex-col gap-7 px-6 py-8 lg:pl-12 lg:pr-[72px] lg:pt-16 lg:pb-12 min-h-screen">
        <div className="flex items-center justify-between lg:hidden">
          <LifeyLogo size={32} />
          <button type="button" onClick={skip} className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 600 }}>
            {t("skip")}
          </button>
        </div>
        <div className="flex flex-col gap-2.5">
          <p className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 600, fontSize: 14 }}>
            {t("stepOf", { step, total: 4 })} · {titles[step]}
          </p>
          <h1 style={{ fontSize: 34, lineHeight: 1.1, fontWeight: 800, letterSpacing: "-0.02em" }}>{titles[step]}</h1>
        </div>

        <div className="flex flex-col gap-5 max-w-[640px]">
          {step === 1 && <GenderBirthDateFields register={register} watch={watch} setValue={setValue} errors={errors} />}
          {step === 2 && <BodyFields register={register} setValue={setValue} errors={errors} unitSystem={unitSystem} />}
          {step === 3 && <LifestyleGoalFields register={register} watch={watch} setValue={setValue} errors={errors} unitSystem={unitSystem} />}
          {step === 4 &&
            (suggestGoalsMutation.isPending || !suggestion ? (
              <p className="type-body py-8" style={{ color: "var(--text-2)" }}>{t("calculating")}</p>
            ) : (
              <>
                <SuggestedPlan plan={suggestion} />
                <p className="type-body-s" style={{ color: "var(--text-3)" }}>{t("changeLater")}</p>
              </>
            ))}
        </div>

        <div className="flex-1" />
        <div className="flex items-center justify-between gap-3">
          <Button variant="secondary" size="auth" onClick={back}>
            <Icon name="arrow_back" size={20} />
            {t("back")}
          </Button>
          {step < 4 ? (
            <Button size="auth" onClick={next}>
              {t("next")}
            </Button>
          ) : (
            <div className="flex gap-2.5">
              <Button variant="secondary" size="auth" onClick={() => finish(false)} disabled={finishing}>
                {t("notNow")}
              </Button>
              <Button size="auth" onClick={() => finish(true)} disabled={finishing || !suggestion}>
                {finishing ? t("saving") : t("applyGoals")}
              </Button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
