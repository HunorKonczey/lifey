"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Button, Drawer } from "@/components/ds";
import { userDetailsApi } from "@/features/onboarding/api";
import { onboardingSchema, type OnboardingFormValues } from "@/features/onboarding/schemas";
import { GenderBirthDateFields } from "@/features/onboarding/components/GenderBirthDateFields";
import { HeightField } from "@/features/onboarding/components/HeightField";
import { LifestyleGoalFields } from "@/features/onboarding/components/LifestyleGoalFields";
import { ConfirmSaveDetailsDialog } from "@/features/onboarding/components/ConfirmSaveDetailsDialog";
import type { UserDetailsField, UserDetailsResponse } from "@/features/onboarding/types";
import { weightApi } from "@/features/weight/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import type { UnitSystem } from "../types";

/**
 * "Profil szerkesztése" (W6-G): the user-details form in a drawer. It is mounted only while open, so it seeds its
 * form from the loaded details once instead of syncing on every refetch. Weight is not edited here (the Weight page
 * owns it): the latest entry only satisfies the shared onboarding schema and is never submitted. Saving still goes
 * through the existing confirm step that lists which changes recalculate the goals.
 */
export function ProfileDrawer({ details, unitSystem, onClose }: { details: UserDetailsResponse; unitSystem: UnitSystem; onClose: () => void }) {
  const t = useTranslations("settings");
  const common = useTranslations("common");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [confirming, setConfirming] = useState(false);

  const { data: weights } = useQuery({ queryKey: queryKeys.weights.all(), queryFn: weightApi.list });
  const latestWeightKg = weights?.length ? [...weights].sort((a, b) => a.date.localeCompare(b.date)).at(-1)!.weight : 70;

  const {
    register, watch, getValues, setValue,
    formState: { errors, isDirty },
    trigger,
  } = useForm<OnboardingFormValues>({
    resolver: zodResolver(onboardingSchema),
    defaultValues: {
      gender: details.gender,
      birthDate: details.birthDate,
      heightCm: details.heightCm,
      activityLevel: details.activityLevel,
      primaryGoal: details.primaryGoal,
      targetWeightKg: details.targetWeightKg ?? undefined,
      currentWeightKg: latestWeightKg,
    },
  });

  const patch = useMutation({
    mutationFn: (body: { fields: UserDetailsField[] } & OnboardingFormValues) =>
      userDetailsApi.patch({
        fields: body.fields,
        gender: body.gender,
        birthDate: body.birthDate,
        heightCm: body.heightCm,
        activityLevel: body.activityLevel,
        primaryGoal: body.primaryGoal,
        targetWeightKg: body.targetWeightKg ?? null,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.userDetails.all() });
      queryClient.invalidateQueries({ queryKey: queryKeys.settings.all() });
      setConfirming(false);
      show(t("settingsSaved"), "success");
      onClose();
    },
    onError: () => show(t("saveSettingsFailed"), "error"),
  });

  async function review() {
    if (await trigger()) setConfirming(true);
  }

  return (
    <>
      <Drawer
        open
        onClose={onClose}
        width={560}
        title={t("editProfile")}
        isDirty={isDirty}
        footer={
          <>
            <Button variant="secondary" onClick={onClose}>{common("cancel")}</Button>
            <Button onClick={review}>{t("saveChanges")}</Button>
          </>
        }
      >
        <div className="flex flex-col gap-6">
          <GenderBirthDateFields register={register} watch={watch} setValue={setValue} errors={errors} />
          <HeightField register={register} setValue={setValue} errors={errors} unitSystem={unitSystem} />
          <LifestyleGoalFields register={register} watch={watch} setValue={setValue} errors={errors} unitSystem={unitSystem} />
        </div>
      </Drawer>
      <ConfirmSaveDetailsDialog
        open={confirming}
        original={details}
        pending={getValues()}
        currentWeightKg={latestWeightKg}
        saving={patch.isPending}
        onClose={() => setConfirming(false)}
        onConfirm={(fields) => patch.mutate({ fields, ...getValues() })}
      />
    </>
  );
}
