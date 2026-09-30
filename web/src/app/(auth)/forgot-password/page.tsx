"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { Button, Icon, PasswordField, TextField } from "@/components/ds";
import {
  forgotPasswordSchema,
  resetPasswordSchema,
  type ForgotPasswordFormValues,
  type ResetPasswordFormValues,
} from "@/features/auth/schemas";
import { authApi } from "@/features/auth/api";
import { ApiError } from "@/lib/api/client";
import { useToast } from "@/lib/hooks/useToast";
import { useValidationMessage } from "@/lib/i18n/useValidationMessage";

type Step = "email" | "reset";

export default function ForgotPasswordPage() {
  const t = useTranslations("auth");
  const vm = useValidationMessage();
  const router = useRouter();
  const { show } = useToast();
  const [step, setStep] = useState<Step>("email");
  const [email, setEmail] = useState("");

  const emailForm = useForm<ForgotPasswordFormValues>({
    resolver: zodResolver(forgotPasswordSchema),
  });

  const resetForm = useForm<ResetPasswordFormValues>({
    resolver: zodResolver(resetPasswordSchema),
  });

  const onSubmitEmail = async (data: ForgotPasswordFormValues) => {
    try {
      await authApi.forgotPassword(data);
      setEmail(data.email);
      setStep("reset");
    } catch (err) {
      const message = err instanceof ApiError ? err.message : t("unexpectedError");
      emailForm.setError("email", { message });
    }
  };

  const onSubmitReset = async (data: ResetPasswordFormValues) => {
    try {
      await authApi.resetPassword({ email, code: data.code, newPassword: data.newPassword });
      show(t("resetSuccess"), "success");
      router.push("/login");
    } catch (err) {
      const message = err instanceof ApiError ? err.message : t("unexpectedError");
      resetForm.setError("code", { message });
    }
  };

  return (
    <div className="flex flex-col gap-[22px] flex-1 lg:flex-none">
      {step === "email" ? (
        <>
          <div className="flex flex-col gap-2">
            <h1 style={{ fontSize: 30, lineHeight: 1.15, fontWeight: 800, letterSpacing: "-0.02em" }}>{t("forgotPasswordTitle")}</h1>
            <p style={{ fontSize: 16, lineHeight: 1.5, color: "var(--text-2)" }}>{t("forgotPasswordTagline")}</p>
          </div>

          <form onSubmit={emailForm.handleSubmit(onSubmitEmail)} className="flex flex-col gap-[22px] flex-1" noValidate>
            <TextField
              size="auth"
              label={t("email")}
              type="email"
              placeholder="you@example.com"
              autoComplete="email"
              error={emailForm.formState.errors.email ? vm(emailForm.formState.errors.email.message) : undefined}
              {...emailForm.register("email")}
            />
            <div className="flex-1 lg:hidden" />
            <Button type="submit" size="auth" fullWidth disabled={emailForm.formState.isSubmitting}>
              {emailForm.formState.isSubmitting ? t("sending") : t("sendCode")}
            </Button>
          </form>
        </>
      ) : (
        <>
          <div className="flex flex-col gap-2">
            <h1 style={{ fontSize: 30, lineHeight: 1.15, fontWeight: 800, letterSpacing: "-0.02em" }}>{t("resetPasswordTitle")}</h1>
            <p style={{ fontSize: 16, lineHeight: 1.5, color: "var(--text-2)" }}>{t("resetPasswordTagline")}</p>
          </div>
          <p
            className="flex items-start gap-2.5 px-3.5 py-3 type-body-s"
            style={{ borderRadius: "var(--r-control)", background: "var(--nested)", color: "var(--text-2)" }}
            role="status"
          >
            <Icon name="mail" size={18} color="var(--text-3)" />
            {t("checkYourEmail")}
          </p>

          <form onSubmit={resetForm.handleSubmit(onSubmitReset)} className="flex flex-col gap-[18px] flex-1" noValidate>
            <TextField
              size="auth"
              label={t("code")}
              inputMode="numeric"
              maxLength={6}
              placeholder="000000"
              autoComplete="one-time-code"
              className="[&_input]:tracking-[0.3em]"
              error={resetForm.formState.errors.code ? vm(resetForm.formState.errors.code.message) : undefined}
              {...resetForm.register("code")}
            />
            <PasswordField
              size="auth"
              label={t("newPassword")}
              placeholder="••••••••"
              autoComplete="new-password"
              error={resetForm.formState.errors.newPassword ? vm(resetForm.formState.errors.newPassword.message) : undefined}
              {...resetForm.register("newPassword")}
            />
            <PasswordField
              size="auth"
              label={t("confirmPassword")}
              placeholder="••••••••"
              autoComplete="new-password"
              error={resetForm.formState.errors.confirmPassword ? vm(resetForm.formState.errors.confirmPassword.message) : undefined}
              {...resetForm.register("confirmPassword")}
            />
            <div className="flex-1 lg:hidden" />
            <Button type="submit" size="auth" fullWidth disabled={resetForm.formState.isSubmitting}>
              {resetForm.formState.isSubmitting ? t("resetting") : t("resetPassword")}
            </Button>
          </form>
        </>
      )}

      <p className="text-center type-body">
        <Link href="/login" style={{ color: "var(--primary)", fontWeight: 700 }}>
          {t("backToLogin")}
        </Link>
      </p>
    </div>
  );
}
