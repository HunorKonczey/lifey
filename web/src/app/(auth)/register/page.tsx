"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { registerSchema, type RegisterFormValues } from "@/features/auth/schemas";
import { authApi } from "@/features/auth/api";
import { useSessionStore } from "@/features/auth/store";
import { GoogleSignInButton } from "@/features/auth/components/GoogleSignInButton";
import { ApiError } from "@/lib/api/client";

export default function RegisterPage() {
  const t = useTranslations("auth");
  const router = useRouter();
  const applyAccessToken = useSessionStore((s) => s.applyAccessToken);

  const {
    register,
    handleSubmit,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<RegisterFormValues>({
    resolver: zodResolver(registerSchema),
  });

  const onSubmit = async (data: RegisterFormValues) => {
    try {
      // Register returns no tokens — log in immediately afterwards.
      await authApi.register({
        email: data.email,
        password: data.password,
        firstName: data.firstName,
        lastName: data.lastName,
      });
      const res = await authApi.login({ email: data.email, password: data.password });
      applyAccessToken(res.accessToken);
      router.push("/onboarding");
    } catch (err) {
      const message =
        err instanceof ApiError ? err.message : t("registrationFailed");
      setError("email", { message });
    }
  };

  return (
    <div
      className="w-full max-w-sm rounded-[var(--r-lg)] p-8"
      style={{ background: "var(--surface)" }}
    >
      <div className="flex items-center gap-2 mb-8">
        <span
          className="material-symbols-rounded text-3xl"
          style={{ color: "var(--primary)", fontVariationSettings: "'FILL' 1" }}
        >
          eco
        </span>
        <span className="text-xl font-bold tracking-tight">Lifey</span>
      </div>

      <h1 className="text-2xl font-bold mb-1">{t("register")}</h1>
      <p className="text-sm mb-8" style={{ color: "var(--on-surface-variant)" }}>
        {t("registerTagline")}
      </p>

      <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
        {(
          [
            { field: "firstName", label: t("firstName"), type: "text", icon: "person", placeholder: "Jane", autoComplete: "given-name" },
            { field: "lastName", label: t("lastName"), type: "text", icon: "person", placeholder: "Doe", autoComplete: "family-name" },
            { field: "email", label: t("email"), type: "email", icon: "mail", placeholder: "you@example.com", autoComplete: "email" },
            { field: "password", label: t("password"), type: "password", icon: "lock", placeholder: "••••••••", autoComplete: "new-password" },
            { field: "confirmPassword", label: t("confirmPassword"), type: "password", icon: "lock", placeholder: "••••••••", autoComplete: "new-password" },
          ] as const
        ).map(({ field, label, type, icon, placeholder, autoComplete }) => (
          <div key={field} className="flex flex-col gap-1">
            <label className="text-sm font-semibold">{label}</label>
            <div
              className="flex items-center gap-2 px-3 rounded-[var(--r-input)] h-11"
              style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}
              data-ring-frame
            >
              <span className="material-symbols-rounded text-base" style={{ color: "var(--muted)" }}>{icon}</span>
              <input
                {...register(field)}
                type={type}
                placeholder={placeholder}
                autoComplete={autoComplete}
                className="flex-1 min-w-0 bg-transparent outline-none text-sm"
              />
            </div>
            {errors[field] && (
              <p className="text-xs" style={{ color: "var(--error)" }}>{errors[field]?.message}</p>
            )}
          </div>
        ))}

        <button
          type="submit"
          disabled={isSubmitting}
          className="mt-2 h-11 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
          style={{ background: "var(--primary)", color: "#1E1F18" }}
        >
          {isSubmitting ? t("creating") : t("register")}
        </button>
      </form>

      <GoogleSignInButton mode="register" />

      <p className="mt-6 text-center text-sm" style={{ color: "var(--on-surface-variant)" }}>
        {t("haveAccount")}{" "}
        <Link href="/login" className="font-semibold" style={{ color: "var(--primary)" }}>
          {t("signIn")}
        </Link>
      </p>
    </div>
  );
}
