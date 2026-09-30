"use client";

import { Suspense } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { useLocale, useTranslations } from "next-intl";
import { Button, PasswordField, TextField } from "@/components/ds";
import { isHuLocale } from "@/lib/format/lifeyFormat";
import { PasswordStrength } from "@/features/auth/components/PasswordStrength";
import { TrainerSignupStepper } from "@/features/auth/components/TrainerSignupStepper";
import { track } from "@vercel/analytics";
import { registerSchema, type RegisterFormValues } from "@/features/auth/schemas";
import { authApi } from "@/features/auth/api";
import { useSessionStore } from "@/features/auth/store";
import { GoogleSignInButton } from "@/features/auth/components/GoogleSignInButton";
import { ApiError } from "@/lib/api/client";
import { extractAttribution, readAttributionCookie } from "@/lib/attribution";
import { useValidationMessage } from "@/lib/i18n/useValidationMessage";

/** A relative, same-origin path only — guards against an open-redirect via `?next=`. */
function safeNextPath(value: string | null): string | null {
  if (!value || !value.startsWith("/") || value.startsWith("//")) return null;
  return value;
}

export default function RegisterPage() {
  return (
    <Suspense fallback={null}>
      <RegisterForm />
    </Suspense>
  );
}

function RegisterForm() {
  const t = useTranslations("auth");
  const vm = useValidationMessage();
  const router = useRouter();
  const searchParams = useSearchParams();
  const applyAccessToken = useSessionStore((s) => s.applyAccessToken);

  const {
    register,
    handleSubmit,
    setError,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<RegisterFormValues>({
    resolver: zodResolver(registerSchema),
  });

  const password = watch("password");
  const locale = useLocale();

  const onSubmit = async (data: RegisterFormValues) => {
    // First-touch (65 D-W8): the lifey_attrib cookie a marketing page wrote
    // on the visitor's *original* touch, days or clicks before this one.
    // Falls back to this page's own current `?src=` — last-touch — only if
    // the cookie is missing entirely (e.g. cookies blocked), so a signup
    // still carries *some* attribution rather than none.
    const signupSource =
      readAttributionCookie(document.cookie) ?? extractAttribution(window.location.search) ?? undefined;

    try {
      // Register returns no tokens — log in immediately afterwards.
      await authApi.register({
        email: data.email,
        password: data.password,
        firstName: data.firstName,
        lastName: data.lastName,
        signupSource,
      });
      track("trainer_request_submitted", { src: signupSource ?? "none" });
      const res = await authApi.login({ email: data.email, password: data.password });
      applyAccessToken(res.accessToken);
      // 66 D-T1: the trainer-request CTA sends visitors here with
      // ?next=/admin/pending so they land straight on the request form
      // instead of the regular onboarding flow.
      router.push(safeNextPath(searchParams.get("next")) ?? "/onboarding");
    } catch (err) {
      const message =
        err instanceof ApiError ? err.message : t("registrationFailed");
      setError("email", { message });
    }
  };

  const trainerPath = (safeNextPath(searchParams.get("next")) ?? "").startsWith("/admin");
  // Surname first in Hungarian, first name first in English (W6-B).
  const hu = isHuLocale(locale);
  const nameFields = [
    <TextField
      key="firstName"
      size="auth"
      label={t("firstName")}
      placeholder={t("firstNamePlaceholder")}
      autoComplete="given-name"
      error={errors.firstName ? vm(errors.firstName.message) : undefined}
      {...register("firstName")}
    />,
    <TextField
      key="lastName"
      size="auth"
      label={t("lastName")}
      placeholder={t("lastNamePlaceholder")}
      autoComplete="family-name"
      error={errors.lastName ? vm(errors.lastName.message) : undefined}
      {...register("lastName")}
    />,
  ];

  return (
    <div className="flex flex-col gap-[18px] flex-1 lg:flex-none">
      {trainerPath && <TrainerSignupStepper />}
      <div className="flex flex-col gap-2">
        <h1 style={{ fontSize: 30, lineHeight: 1.15, fontWeight: 800, letterSpacing: "-0.02em" }}>
          {trainerPath ? t("trainerRegisterTitle") : t("registerTitle")}
        </h1>
        {!trainerPath && <p style={{ fontSize: 16, lineHeight: 1.5, color: "var(--text-2)" }}>{t("registerTagline")}</p>}
      </div>

      {!trainerPath && <GoogleSignInButton mode="register" />}

      <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-[18px] flex-1" noValidate>
        <div className="grid grid-cols-2 gap-3">{hu ? [...nameFields].reverse() : nameFields}</div>
        <TextField
          size="auth"
          label={t("email")}
          type="email"
          placeholder="you@example.com"
          autoComplete="email"
          error={errors.email ? vm(errors.email.message) : undefined}
          {...register("email")}
        />
        <div>
          <PasswordField
            size="auth"
            label={t("password")}
            placeholder="••••••••"
            autoComplete="new-password"
            error={errors.password ? vm(errors.password.message) : undefined}
            {...register("password")}
          />
          <PasswordStrength password={password ?? ""} />
        </div>

        <div className="flex-1 lg:hidden" />
        <Button type="submit" size="auth" fullWidth disabled={isSubmitting}>
          {isSubmitting ? t("creating") : trainerPath ? t("trainerContinue") : t("register")}
        </Button>
      </form>

      <p className="text-center type-body" style={{ color: "var(--text-2)" }}>
        {t("haveAccount")}{" "}
        <Link href="/login" style={{ color: "var(--primary)", fontWeight: 700 }}>
          {t("signIn")}
        </Link>
      </p>
    </div>
  );
}
