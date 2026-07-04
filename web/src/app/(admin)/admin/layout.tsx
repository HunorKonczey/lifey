"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useSessionStore } from "@/features/auth/store";
import { AdminSidebar } from "@/components/layout/AdminSidebar";
import { useUiStore } from "@/lib/hooks/useUiStore";
import { ErrorBoundary } from "@/components/status/ErrorBoundary";

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const { user, isLoading, initialize } = useSessionStore();
  const common = useTranslations("common");
  const toggleDrawer = useUiStore((s) => s.toggleDrawer);

  useEffect(() => {
    initialize();
  }, [initialize]);

  useEffect(() => {
    if (isLoading) return;
    if (!user) {
      router.push("/login");
      return;
    }
    if (!user.roles.includes("ROLE_TRAINER")) {
      router.push("/dashboard");
    }
  }, [isLoading, user, router]);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-bg">
        <span
          className="material-symbols-rounded text-4xl animate-pulse"
          style={{ color: "var(--tertiary)" }}
        >
          eco
        </span>
      </div>
    );
  }

  if (!user || !user.roles.includes("ROLE_TRAINER")) return null;

  return (
    <div className="flex min-h-screen bg-bg">
      <AdminSidebar />
      <div className="flex flex-col flex-1 min-w-0">
        <button
          onClick={toggleDrawer}
          className="m-3 p-2 rounded-[var(--r-sm)] transition-colors hover:bg-surface-container md:hidden self-start"
          style={{ color: "var(--on-surface)" }}
          aria-label={common("openMenu")}
        >
          <span className="material-symbols-rounded text-xl">menu</span>
        </button>
        <main className="flex-1 p-3.5 pt-0 md:pt-3.5 overflow-auto">
          <ErrorBoundary>{children}</ErrorBoundary>
        </main>
      </div>
    </div>
  );
}
