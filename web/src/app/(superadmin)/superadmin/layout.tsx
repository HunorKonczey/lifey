"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { Providers } from "@/lib/providers";
import { useSessionStore } from "@/features/auth/store";
import { AppShell } from "@/components/shell/AppShell";
import { SUPERADMIN_NAV_GROUPS, SUPERADMIN_NAV_ITEMS } from "@/components/shell/navConfig";
import { ErrorBoundary } from "@/components/status/ErrorBoundary";

// `<Providers>` has to wrap this gate rather than the other way round —
// SuperAdminGate calls hooks (useTranslations, ...) that need to be a
// *descendant* of QueryClientProvider/I18nProvider, not their own ancestor.
export default function SuperAdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <Providers>
      <SuperAdminGate>{children}</SuperAdminGate>
    </Providers>
  );
}

function SuperAdminGate({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const { user, isLoading, initialize, logout } = useSessionStore();
  const superadmin = useTranslations("superadmin");

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
        <span aria-hidden="true" className="material-symbols-rounded text-4xl animate-pulse" style={{ color: "var(--text-2)" }}>
          eco
        </span>
      </div>
    );
  }

  if (!user || !user.roles.includes("ROLE_SUPER_ADMIN")) return null;

  return (
    <AppShell
      user={user}
      onLogout={logout}
      groups={SUPERADMIN_NAV_GROUPS}
      bottomNavItems={SUPERADMIN_NAV_ITEMS}
      moreSheetItems={[]}
      roleBadge={{ icon: "shield_person", label: superadmin("chip") }}
      roleRing="superadmin"
      showSettingsRow={false}
    >
      <ErrorBoundary>{children}</ErrorBoundary>
    </AppShell>
  );
}
