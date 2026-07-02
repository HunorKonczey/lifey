"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { settingsApi } from "@/features/settings/api";
import { authApi } from "@/features/auth/api";
import { changePasswordSchema, type ChangePasswordFormValues } from "@/features/auth/schemas";
import { userDetailsApi } from "@/features/onboarding/api";
import { onboardingSchema, type OnboardingFormValues } from "@/features/onboarding/schemas";
import { GenderBirthDateFields } from "@/features/onboarding/components/GenderBirthDateFields";
import { HeightField } from "@/features/onboarding/components/HeightField";
import { LifestyleGoalFields } from "@/features/onboarding/components/LifestyleGoalFields";
import { weightApi } from "@/features/weight/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { ApiError } from "@/lib/api/client";
import { useToast } from "@/lib/hooks/useToast";
import { useTheme } from "@/lib/hooks/useTheme";
import { useLocale } from "@/lib/hooks/useLocale";
import { useSessionStore } from "@/features/auth/store";
import { SegmentedControl } from "@/components/ui/SegmentedControl";
import { Skeleton } from "@/components/status/Skeleton";
import { ErrorState } from "@/components/status/ErrorState";
import type {
  SettingsResponse, UnitSystem, ThemePreference, LanguagePreference,
} from "@/features/settings/types";

type Section = "profile" | "goals" | "units" | "theme" | "language" | "security";

export default function SettingsPage() {
  const t = useTranslations("settings");
  const d = useTranslations("dashboard");
  const queryClient = useQueryClient();

  const SECTIONS: { value: Section; label: string; icon: string }[] = [
    { value: "profile", label: t("profile"), icon: "person" },
    { value: "goals", label: t("dailyGoals"), icon: "target" },
    { value: "units", label: t("units"), icon: "straighten" },
    { value: "theme", label: t("theme"), icon: "palette" },
    { value: "language", label: t("language"), icon: "translate" },
    { value: "security", label: t("security"), icon: "shield" },
  ];

  const GOAL_FIELDS: { key: keyof SettingsResponse; label: string; color: string; unit: string }[] = [
    { key: "dailyCalorieGoal", label: d("calories"), color: "var(--metric-kcal)", unit: "kcal" },
    { key: "dailyProteinGoal", label: d("protein"), color: "var(--metric-protein)", unit: "g" },
    { key: "dailyCarbsGoal", label: d("carbs"), color: "var(--metric-carbs)", unit: "g" },
    { key: "dailyFatGoal", label: d("fat"), color: "var(--metric-fat)", unit: "g" },
    { key: "dailyWaterGoalLiters", label: d("water"), color: "var(--metric-water)", unit: "L" },
    { key: "dailyStepGoal", label: d("steps"), color: "var(--metric-steps)", unit: "" },
  ];
  const { show } = useToast();
  const { setTheme } = useTheme();
  const { setLanguage } = useLocale();
  const { user, logoutAll, applyAccessToken } = useSessionStore();
  const [section, setSection] = useState<Section>("profile");
  const [form, setForm] = useState<SettingsResponse | null>(null);
  const [seededFrom, setSeededFrom] = useState<SettingsResponse | null>(null);

  const {
    register: registerPassword,
    handleSubmit: handlePasswordSubmit,
    reset: resetPasswordForm,
    setError: setPasswordError,
    formState: { errors: passwordErrors, isSubmitting: isChangingPassword },
  } = useForm<ChangePasswordFormValues>({ resolver: zodResolver(changePasswordSchema) });

  const changePasswordMutation = useMutation({
    mutationFn: (body: ChangePasswordFormValues) =>
      authApi.changePassword({ currentPassword: body.currentPassword, newPassword: body.newPassword }),
    onSuccess: (res) => {
      applyAccessToken(res.accessToken, res.refreshToken);
      resetPasswordForm();
      show(t("changePasswordSuccess"), "success");
    },
    onError: (err) => {
      const message = err instanceof ApiError ? err.message : t("changePasswordError");
      setPasswordError("currentPassword", { message });
    },
  });

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.settings.all(),
    queryFn: settingsApi.get,
  });

  // Seed editable form from query data during render (React-recommended pattern
  // for syncing state to a changing prop/source — avoids setState-in-effect).
  if (data && data !== seededFrom) {
    setSeededFrom(data);
    setForm(data);
  }

  const router = useRouter();

  const {
    data: details, error: detailsError,
  } = useQuery({
    queryKey: queryKeys.userDetails.all(),
    queryFn: userDetailsApi.get,
    retry: false,
  });
  const notOnboarded = detailsError instanceof ApiError && detailsError.status === 404;

  // The wizard's field components share OnboardingFormValues (which includes
  // currentWeightKg, needed there to seed the first weight_entries row).
  // Profile editing here never touches weight — it's edited via the Weight
  // page — so currentWeightKg is seeded from the latest weight entry purely
  // to satisfy the shared schema's validation and is never submitted below.
  const { data: weights } = useQuery({ queryKey: queryKeys.weights.all(), queryFn: weightApi.list });
  const latestWeightKg = weights?.length
    ? [...weights].sort((a, b) => a.date.localeCompare(b.date)).at(-1)!.weight
    : 70;

  const {
    register: registerDetails, watch: watchDetails, getValues: getDetailsValues,
    setValue: setDetailsValue, reset: resetDetailsForm,
    formState: { errors: detailsErrors },
  } = useForm<OnboardingFormValues>({ resolver: zodResolver(onboardingSchema) });
  const [detailsSeededFrom, setDetailsSeededFrom] = useState<typeof details>(undefined);

  if (details && details !== detailsSeededFrom) {
    setDetailsSeededFrom(details);
    resetDetailsForm({
      gender: details.gender,
      birthDate: details.birthDate,
      heightCm: details.heightCm,
      activityLevel: details.activityLevel,
      primaryGoal: details.primaryGoal,
      targetWeightKg: details.targetWeightKg ?? undefined,
      currentWeightKg: latestWeightKg,
    });
  }

  const saveDetailsMutation = useMutation({
    mutationFn: (body: OnboardingFormValues) =>
      userDetailsApi.update({
        gender: body.gender,
        birthDate: body.birthDate,
        heightCm: body.heightCm,
        activityLevel: body.activityLevel,
        primaryGoal: body.primaryGoal,
        targetWeightKg: body.targetWeightKg ?? null,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.userDetails.all() });
      show(t("settingsSaved"), "success");
    },
    onError: () => show(t("saveSettingsFailed"), "error"),
  });

  const saveMutation = useMutation({
    mutationFn: (body: SettingsResponse) => settingsApi.update(body),
    onSuccess: (saved) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.settings.all() });
      setForm(saved);
      show(t("settingsSaved"), "success");
    },
    onError: () => show(t("saveSettingsFailed"), "error"),
  });

  if (isLoading || !form) return <Skeleton variant="card" className="h-96" />;
  if (isError) return <ErrorState onRetry={refetch} />;

  const patch = (p: Partial<SettingsResponse>) => setForm((f) => f ? { ...f, ...p } : f);
  const saveImmediate = (p: Partial<SettingsResponse>) => {
    const next = { ...form, ...p };
    setForm(next);
    saveMutation.mutate(next);
  };

  return (
    <div className="flex gap-6">
      {/* Sub-nav */}
      <div className="w-[200px] shrink-0 flex flex-col gap-1">
        {SECTIONS.map((s) => (
          <button key={s.value} onClick={() => setSection(s.value)}
            className="flex items-center gap-3 px-3 py-2.5 rounded-[var(--r-card)] text-left transition-colors"
            style={{
              background: section === s.value ? "var(--primary)" : "transparent",
              color: section === s.value ? "#1E1F18" : "var(--on-surface-variant)",
            }}>
            <span className="material-symbols-rounded text-xl">{s.icon}</span>
            <span className="text-sm font-semibold">{s.label}</span>
          </button>
        ))}
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0 rounded-[var(--r-lg)] p-6" style={{ background: "var(--surface)" }}>
        {section === "profile" && (
          <Panel title={t("profile")}>
            <Field label={t("email")}>
              <ReadonlyValue>{user?.email ?? "—"}</ReadonlyValue>
            </Field>
            <Field label={t("roles")}>
              <ReadonlyValue>{user?.roles.join(", ") ?? "—"}</ReadonlyValue>
            </Field>

            <hr style={{ borderColor: "var(--outline)" }} />

            {notOnboarded ? (
              <div className="flex flex-col gap-2">
                <p className="text-sm" style={{ color: "var(--on-surface-variant)" }}>
                  {t("onboardingNotDone")}
                </p>
                <button onClick={() => router.push("/onboarding")}
                  className="h-10 px-5 w-fit rounded-[var(--r-input)] font-semibold text-sm"
                  style={{ background: "var(--primary)", color: "#1E1F18" }}>
                  {t("startOnboarding")}
                </button>
              </div>
            ) : !details ? (
              <Skeleton variant="text" />
            ) : (
              <>
                <p className="text-sm font-bold">{t("bodyAndGoals")}</p>
                <GenderBirthDateFields register={registerDetails} watch={watchDetails} setValue={setDetailsValue} errors={detailsErrors} />
                <HeightField register={registerDetails} setValue={setDetailsValue} errors={detailsErrors} unitSystem={form.unitSystem} />
                <LifestyleGoalFields register={registerDetails} watch={watchDetails} setValue={setDetailsValue} errors={detailsErrors} unitSystem={form.unitSystem} />
                <button
                  onClick={() => saveDetailsMutation.mutate(getDetailsValues())}
                  disabled={saveDetailsMutation.isPending}
                  className="mt-1 h-10 px-6 w-fit rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
                  style={{ background: "var(--primary)", color: "#1E1F18" }}>
                  {saveDetailsMutation.isPending ? t("saving") : t("saveChanges")}
                </button>
              </>
            )}
          </Panel>
        )}

        {section === "goals" && (
          <Panel title={t("dailyGoals")}>
            <div className="grid grid-cols-2 gap-4">
              {GOAL_FIELDS.map(({ key, label, color, unit }) => (
                <div key={key} className="flex flex-col gap-1.5 p-3 rounded-[var(--r-card)]"
                  style={{ background: "var(--surface-container)" }}>
                  <label className="text-xs font-semibold" style={{ color }}>{label} {unit && `(${unit})`}</label>
                  <input type="number" min={0}
                    step={key === "dailyWaterGoalLiters" ? "0.1" : "1"}
                    value={(form[key] as number | null) ?? ""}
                    onChange={(e) => patch({ [key]: e.target.value === "" ? null : Number(e.target.value) })}
                    className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm tabular"
                    style={{ background: "var(--surface)", border: "1px solid var(--outline)" }} />
                </div>
              ))}
            </div>
            <button onClick={() => saveMutation.mutate(form)} disabled={saveMutation.isPending}
              className="mt-5 h-10 px-6 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
              style={{ background: "var(--primary)", color: "#1E1F18" }}>
              {saveMutation.isPending ? t("saving") : t("saveChanges")}
            </button>
          </Panel>
        )}

        {section === "units" && (
          <Panel title={t("units")}>
            <SegmentedControl<UnitSystem>
              options={[{ value: "METRIC", label: t("metric") }, { value: "IMPERIAL", label: t("imperial") }]}
              value={form.unitSystem}
              onChange={(v) => saveImmediate({ unitSystem: v })}
            />
          </Panel>
        )}

        {section === "theme" && (
          <Panel title={t("theme")}>
            <SegmentedControl<ThemePreference>
              options={[
                { value: "LIGHT", label: t("light") },
                { value: "DARK", label: t("dark") },
                { value: "SYSTEM", label: t("system") },
              ]}
              value={form.theme}
              onChange={(v) => {
                setTheme(v.toLowerCase() as "light" | "dark" | "system");
                saveImmediate({ theme: v });
              }}
            />
            <p className="text-xs mt-3" style={{ color: "var(--muted)" }}>{t("appliedImmediately")}</p>
          </Panel>
        )}

        {section === "language" && (
          <Panel title={t("language")}>
            <SegmentedControl<LanguagePreference>
              options={[
                { value: "SYSTEM", label: t("system") },
                { value: "ENGLISH", label: t("english") },
                { value: "HUNGARIAN", label: t("hungarian") },
              ]}
              value={form.language}
              onChange={(v) => { setLanguage(v); saveImmediate({ language: v }); }}
            />
          </Panel>
        )}

        {section === "security" && (
          <Panel title={t("security")}>
            <form
              onSubmit={handlePasswordSubmit((data) => changePasswordMutation.mutate(data))}
              className="flex flex-col gap-4 mb-6"
            >
              {(
                [
                  { field: "currentPassword", label: t("currentPassword"), autoComplete: "current-password" },
                  { field: "newPassword", label: t("newPassword"), autoComplete: "new-password" },
                  { field: "confirmPassword", label: t("confirmNewPassword"), autoComplete: "new-password" },
                ] as const
              ).map(({ field, label, autoComplete }) => (
                <Field key={field} label={label}>
                  <input
                    {...registerPassword(field)}
                    type="password"
                    placeholder="••••••••"
                    autoComplete={autoComplete}
                    className="px-3 h-10 rounded-[var(--r-input)] outline-none text-sm"
                    style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
                  />
                  {passwordErrors[field] && (
                    <p className="text-xs" style={{ color: "var(--error)" }}>{passwordErrors[field]?.message}</p>
                  )}
                </Field>
              ))}
              <button type="submit" disabled={isChangingPassword}
                className="h-10 px-6 w-fit rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
                style={{ background: "var(--primary)", color: "#1E1F18" }}>
                {t("changePassword")}
              </button>
            </form>

            <button onClick={() => logoutAll()}
              className="flex items-center gap-2 h-10 px-5 rounded-[var(--r-input)] font-semibold text-sm"
              style={{ background: "color-mix(in srgb, var(--error) 15%, transparent)", color: "var(--error)" }}>
              <span className="material-symbols-rounded text-lg">logout</span>
              {t("logoutAll")}
            </button>
          </Panel>
        )}
      </div>
    </div>
  );
}

function Panel({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <h2 className="text-lg font-bold mb-5">{title}</h2>
      <div className="flex flex-col gap-4 max-w-lg">{children}</div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-1">
      <label className="text-xs font-semibold" style={{ color: "var(--on-surface-variant)" }}>{label}</label>
      {children}
    </div>
  );
}

function ReadonlyValue({ children }: { children: React.ReactNode }) {
  return (
    <div className="px-3 h-10 flex items-center rounded-[var(--r-input)] text-sm"
      style={{ background: "var(--surface-container)", border: "1px solid var(--outline)", color: "var(--on-surface-variant)" }}>
      {children}
    </div>
  );
}
