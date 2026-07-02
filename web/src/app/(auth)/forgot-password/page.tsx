"use client";

import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useTranslations } from "next-intl";
import {
  forgotPasswordSchema,
  resetPasswordSchema,
  type ForgotPasswordFormValues,
  type ResetPasswordFormValues,
} from "@/features/auth/schemas";
import { authApi } from "@/features/auth/api";
import { ApiError } from "@/lib/api/client";
import { useToast } from "@/lib/hooks/useToast";

type Step = "email" | "reset";

export default function ForgotPasswordPage() {
  const t = useTranslations("auth");
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
      const message = err instanceof ApiError ? err.message : "An unexpected error occurred";
      emailForm.setError("email", { message });
    }
  };

  const onSubmitReset = async (data: ResetPasswordFormValues) => {
    try {
      await authApi.resetPassword({ email, code: data.code, newPassword: data.newPassword });
      show(t("resetSuccess"), "success");
      router.push("/login");
    } catch (err) {
      const message = err instanceof ApiError ? err.message : "An unexpected error occurred";
      resetForm.setError("code", { message });
    }
  };

  return (
    <div
      className="w-full max-w-sm rounded-[var(--r-lg)] p-8"
      style={{ background: "var(--surface)" }}
    >
      {/* Logo */}
      <div className="flex items-center gap-2 mb-8">
        <span
          className="material-symbols-rounded text-3xl"
          style={{ color: "var(--primary)", fontVariationSettings: "'FILL' 1" }}
        >
          eco
        </span>
        <span className="text-xl font-bold tracking-tight">Lifey</span>
      </div>

      {step === "email" ? (
        <>
          <h1 className="text-2xl font-bold mb-1">{t("forgotPasswordTitle")}</h1>
          <p className="text-sm mb-8" style={{ color: "var(--on-surface-variant)" }}>
            {t("forgotPasswordTagline")}
          </p>

          <form onSubmit={emailForm.handleSubmit(onSubmitEmail)} className="flex flex-col gap-4">
            <div className="flex flex-col gap-1">
              <label className="text-sm font-semibold">{t("email")}</label>
              <div
                className="flex items-center gap-2 px-3 rounded-[var(--r-input)] h-11"
                style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
                data-ring-frame
              >
                <span className="material-symbols-rounded text-base" style={{ color: "var(--muted)" }}>mail</span>
                <input
                  {...emailForm.register("email")}
                  type="email"
                  placeholder="you@example.com"
                  className="flex-1 min-w-0 bg-transparent outline-none text-sm"
                  autoComplete="email"
                />
              </div>
              {emailForm.formState.errors.email && (
                <p className="text-xs" style={{ color: "var(--error)" }}>
                  {emailForm.formState.errors.email.message}
                </p>
              )}
            </div>

            <button
              type="submit"
              disabled={emailForm.formState.isSubmitting}
              className="mt-2 h-11 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
              style={{ background: "var(--primary)", color: "#1E1F18" }}
            >
              {emailForm.formState.isSubmitting ? t("sending") : t("sendCode")}
            </button>
          </form>
        </>
      ) : (
        <>
          <h1 className="text-2xl font-bold mb-1">{t("resetPasswordTitle")}</h1>
          <p className="text-sm mb-4" style={{ color: "var(--on-surface-variant)" }}>
            {t("resetPasswordTagline")}
          </p>
          <p
            className="text-xs mb-6 px-3 py-2 rounded-[var(--r-input)]"
            style={{ background: "var(--surface-container)", color: "var(--on-surface-variant)" }}
          >
            {t("checkYourEmail")}
          </p>

          <form onSubmit={resetForm.handleSubmit(onSubmitReset)} className="flex flex-col gap-4">
            <div className="flex flex-col gap-1">
              <label className="text-sm font-semibold">{t("code")}</label>
              <div
                className="flex items-center gap-2 px-3 rounded-[var(--r-input)] h-11"
                style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
                data-ring-frame
              >
                <span className="material-symbols-rounded text-base" style={{ color: "var(--muted)" }}>pin</span>
                <input
                  {...resetForm.register("code")}
                  type="text"
                  inputMode="numeric"
                  maxLength={6}
                  placeholder="000000"
                  className="flex-1 min-w-0 bg-transparent outline-none text-sm tracking-[0.3em]"
                  autoComplete="one-time-code"
                />
              </div>
              {resetForm.formState.errors.code && (
                <p className="text-xs" style={{ color: "var(--error)" }}>
                  {resetForm.formState.errors.code.message}
                </p>
              )}
            </div>

            {(
              [
                { field: "newPassword", label: t("newPassword") },
                { field: "confirmPassword", label: t("confirmPassword") },
              ] as const
            ).map(({ field, label }) => (
              <div key={field} className="flex flex-col gap-1">
                <label className="text-sm font-semibold">{label}</label>
                <div
                  className="flex items-center gap-2 px-3 rounded-[var(--r-input)] h-11"
                  style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
                >
                  <span className="material-symbols-rounded text-base" style={{ color: "var(--muted)" }}>lock</span>
                  <input
                    {...resetForm.register(field)}
                    type="password"
                    placeholder="••••••••"
                    autoComplete="new-password"
                    className="flex-1 min-w-0 bg-transparent outline-none text-sm"
                  />
                </div>
                {resetForm.formState.errors[field] && (
                  <p className="text-xs" style={{ color: "var(--error)" }}>
                    {resetForm.formState.errors[field]?.message}
                  </p>
                )}
              </div>
            ))}

            <button
              type="submit"
              disabled={resetForm.formState.isSubmitting}
              className="mt-2 h-11 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
              style={{ background: "var(--primary)", color: "#1E1F18" }}
            >
              {resetForm.formState.isSubmitting ? t("resetting") : t("resetPassword")}
            </button>
          </form>
        </>
      )}

      <p className="mt-6 text-center text-sm" style={{ color: "var(--on-surface-variant)" }}>
        <Link href="/login" className="font-semibold" style={{ color: "var(--primary)" }}>
          {t("backToLogin")}
        </Link>
      </p>
    </div>
  );
}
