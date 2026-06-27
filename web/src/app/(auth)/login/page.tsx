"use client";

import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { loginSchema, type LoginFormValues } from "@/features/auth/schemas";
import { authApi } from "@/features/auth/api";
import { useSessionStore } from "@/features/auth/store";
import { ApiError } from "@/lib/api/client";

export default function LoginPage() {
  const router = useRouter();
  const setUser = useSessionStore((s) => s.setUser);

  const {
    register,
    handleSubmit,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormValues>({
    resolver: zodResolver(loginSchema),
  });

  const onSubmit = async (data: LoginFormValues) => {
    try {
      const res = await authApi.login(data);
      setUser(res.user, res.accessToken);
      router.push("/dashboard");
    } catch (err) {
      const message =
        err instanceof ApiError
          ? err.message
          : "An unexpected error occurred";
      setError("password", { message });
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

      <h1 className="text-2xl font-bold mb-1">Welcome back</h1>
      <p className="text-sm mb-8" style={{ color: "var(--on-surface-variant)" }}>
        Sign in to continue tracking your progress
      </p>

      <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
        <div className="flex flex-col gap-1">
          <label className="text-sm font-semibold">Email</label>
          <div className="flex items-center gap-2 px-3 rounded-[var(--r-input)] h-11"
            style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}>
            <span className="material-symbols-rounded text-base" style={{ color: "var(--muted)" }}>mail</span>
            <input
              {...register("email")}
              type="email"
              placeholder="you@example.com"
              className="flex-1 bg-transparent outline-none text-sm"
              autoComplete="email"
            />
          </div>
          {errors.email && (
            <p className="text-xs" style={{ color: "var(--error)" }}>{errors.email.message}</p>
          )}
        </div>

        <div className="flex flex-col gap-1">
          <label className="text-sm font-semibold">Password</label>
          <div className="flex items-center gap-2 px-3 rounded-[var(--r-input)] h-11"
            style={{ background: "var(--surface-container)", border: "1px solid var(--outline)" }}>
            <span className="material-symbols-rounded text-base" style={{ color: "var(--muted)" }}>lock</span>
            <input
              {...register("password")}
              type="password"
              placeholder="••••••••"
              className="flex-1 bg-transparent outline-none text-sm"
              autoComplete="current-password"
            />
          </div>
          {errors.password && (
            <p className="text-xs" style={{ color: "var(--error)" }}>{errors.password.message}</p>
          )}
        </div>

        <button
          type="submit"
          disabled={isSubmitting}
          className="mt-2 h-11 rounded-[var(--r-input)] font-semibold text-sm transition-opacity disabled:opacity-60"
          style={{ background: "var(--primary)", color: "#1E1F18" }}
        >
          {isSubmitting ? "Signing in…" : "Sign in"}
        </button>
      </form>

      <p className="mt-6 text-center text-sm" style={{ color: "var(--on-surface-variant)" }}>
        Don&apos;t have an account?{" "}
        <Link href="/register" className="font-semibold" style={{ color: "var(--primary)" }}>
          Create one
        </Link>
      </p>
    </div>
  );
}
