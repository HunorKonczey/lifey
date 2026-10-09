"use client";

import { Suspense, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { Button, PasswordField, TextField } from "@/components/ds";
import { loginSchema, type LoginFormValues } from "@/features/auth/schemas";
import { authApi } from "@/features/auth/api";
import { useSessionStore } from "@/features/auth/store";
import { GoogleSignInButton } from "@/features/auth/components/GoogleSignInButton";
import { safeNextPath, withNext } from "@/features/auth/nextPath";
import { FormErrorBox } from "@/features/auth/components/FormErrorBox";
import { ApiError } from "@/lib/api/client";
import { useValidationMessage } from "@/lib/i18n/useValidationMessage";

/**
 * W6-A / W6.2: "Üdv újra!", the Google button, a divider, then the form. A wrong password is not pinned on one field:
 * both get the red ring and a tinted box above the button says what to do (W6 note "Hiba, amit nem lehet nem
 * észrevenni") — announced to screen readers as an alert.
 */
export default function LoginPage() {
  return (
    <Suspense fallback={null}>
      <LoginForm />
    </Suspense>
  );
}

function LoginForm() {
  const t = useTranslations("auth");
  const vm = useValidationMessage();
  const router = useRouter();
  // Where the visitor was headed (a join link, say); only a path of this site is followed.
  const next = safeNextPath(useSearchParams().get("next"));
  const applyAccessToken = useSessionStore((s) => s.applyAccessToken);
  const [formError, setFormError] = useState<string | null>(null);

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormValues>({ resolver: zodResolver(loginSchema) });

  const onSubmit = async (data: LoginFormValues) => {
    setFormError(null);
    try {
      const res = await authApi.login(data);
      applyAccessToken(res.accessToken, res.refreshToken);
      router.push(next ?? "/dashboard");
    } catch (err) {
      // 401 is always bad credentials; the backend's English text must not reach a Hungarian UI.
      setFormError(err instanceof ApiError ? (err.status === 401 ? t("invalidCredentialsLong") : err.message) : t("unexpectedError"));
    }
  };

  const rung = !!formError;

  return (
    <div className="flex flex-col gap-[22px] flex-1 lg:flex-none">
      <div className="flex flex-col gap-2">
        <h1 style={{ fontSize: 34, lineHeight: 1.1, fontWeight: 800, letterSpacing: "-0.02em" }}>{t("welcomeBack")}</h1>
        <p style={{ fontSize: 16, lineHeight: 1.5, color: "var(--text-2)" }}>{t("loginTagline")}</p>
      </div>

      <GoogleSignInButton redirectTo={next ?? undefined} />

      <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-[22px] flex-1" noValidate>
        <TextField
          size="auth"
          label={t("email")}
          type="email"
          placeholder="you@example.com"
          autoComplete="email"
          error={errors.email ? vm(errors.email.message) : undefined}
          invalid={rung}
          {...register("email")}
        />
        <div>
          <div className="flex items-center justify-between mb-1.5">
            <span className="type-label" style={{ color: "var(--text-3)" }} aria-hidden>
              {t("password")}
            </span>
            <Link href="/forgot-password" className="type-body-s" style={{ color: "var(--primary)", fontWeight: 700 }}>
              {t("forgotPassword")}
            </Link>
          </div>
          <PasswordField
            size="auth"
            aria-label={t("password")}
            placeholder="••••••••"
            autoComplete="current-password"
            error={errors.password ? vm(errors.password.message) : undefined}
            invalid={rung}
            {...register("password")}
          />
        </div>

        {formError && <FormErrorBox message={formError} />}

        <div className="flex-1 lg:hidden" />
        <Button type="submit" size="auth" fullWidth disabled={isSubmitting}>
          {isSubmitting ? t("signingIn") : t("signIn")}
        </Button>
      </form>

      <p className="text-center type-body" style={{ color: "var(--text-2)" }}>
        {t("noAccountShort")}{" "}
        <Link href={withNext("/register", next)} style={{ color: "var(--primary)", fontWeight: 700 }}>
          {t("signUp")}
        </Link>
      </p>
    </div>
  );
}
