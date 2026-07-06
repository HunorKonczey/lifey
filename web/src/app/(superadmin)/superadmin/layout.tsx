"use client";

import { useEffect, useMemo } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import Link from "next/link";
import { useSessionStore } from "@/features/auth/store";
import { ThemeToggle } from "@/components/layout/ThemeToggle";
import { ErrorBoundary } from "@/components/status/ErrorBoundary";
import { avatarApi } from "@/features/settings/api";
import { queryKeys } from "@/lib/api/queryKeys";

export default function SuperAdminLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const { user, isLoading, initialize } = useSessionStore();
  const superadmin = useTranslations("superadmin");

  const { data: avatarBlob } = useQuery({
    queryKey: queryKeys.settings.avatar(),
    queryFn: avatarApi.get,
    enabled: !!user,
    staleTime: 5 * 60 * 1000,
  });
  const avatarUrl = useMemo(() => (avatarBlob ? URL.createObjectURL(avatarBlob) : null), [avatarBlob]);
  useEffect(() => {
    return () => {
      if (avatarUrl) URL.revokeObjectURL(avatarUrl);
    };
  }, [avatarUrl]);

  useEffect(() => {
    initialize();
  }, [initialize]);

  useEffect(() => {
    if (isLoading) return;
    if (!user) {
      router.push("/login");
      return;
    }
    if (!user.roles.includes("ROLE_SUPER_ADMIN")) {
      router.push("/dashboard");
    }
  }, [isLoading, user, router]);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-bg">
        <span className="material-symbols-rounded text-4xl animate-pulse" style={{ color: "var(--on-surface-variant)" }}>
          eco
        </span>
      </div>
    );
  }

  if (!user || !user.roles.includes("ROLE_SUPER_ADMIN")) return null;

  return (
    <div className="min-h-screen bg-bg p-3.5">
      <header
        className="flex items-center justify-between rounded-[18px] h-[58px] pl-4.5 pr-3 mb-4"
        style={{ background: "var(--surface-high)" }}
      >
        <div className="flex items-center gap-2.5">
          <div
            className="w-[34px] h-[34px] rounded-[11px] flex items-center justify-center"
            style={{ background: "var(--primary)", color: "#161611" }}
          >
            <span className="material-symbols-rounded text-xl" style={{ fontVariationSettings: "'FILL' 1" }}>
              eco
            </span>
          </div>
          <span className="font-extrabold text-[17px] tracking-tight" style={{ color: "var(--on-surface)" }}>
            Lifey
          </span>
          <span
            className="flex items-center gap-1.5 rounded-[var(--r-pill)] text-[10px] font-extrabold tracking-wide px-2.5 py-1"
            style={{ border: "1.5px solid var(--muted)", color: "var(--on-surface)" }}
          >
            <span className="material-symbols-rounded text-[13px]">shield_person</span>
            {superadmin("chip")}
          </span>
          <Link
            href="/dashboard"
            className="ml-3 text-sm font-semibold transition-colors"
            style={{ color: "var(--on-surface-variant)" }}
          >
            {superadmin("backToOwnView")}
          </Link>
        </div>
        <div className="flex items-center gap-2">
          <ThemeToggle />
          <div
            className="w-[38px] h-[38px] rounded-xl flex items-center justify-center text-sm font-extrabold overflow-hidden"
            style={{ background: "var(--tertiary)", color: "#161611" }}
          >
            {avatarUrl ? (
              // Blob object URLs aren't compatible with next/image's optimizer.
              // eslint-disable-next-line @next/next/no-img-element
              <img src={avatarUrl} alt="" className="w-full h-full object-cover" />
            ) : (
              user.email.charAt(0).toUpperCase()
            )}
          </div>
        </div>
      </header>
      <main>
        <ErrorBoundary>{children}</ErrorBoundary>
      </main>
    </div>
  );
}
