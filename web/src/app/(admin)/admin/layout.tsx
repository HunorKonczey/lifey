"use client";

import { useEffect } from "react";
import { useRouter, usePathname } from "next/navigation";
import { useTranslations } from "next-intl";
import { Providers } from "@/lib/providers";
import { useSessionStore } from "@/features/auth/store";
import { AppShell } from "@/components/shell/AppShell";
import { TRAINER_NAV_GROUPS, TRAINER_NAV_ITEMS, TRAINER_MORE_SHEET_ITEMS } from "@/components/shell/navConfig";
import { ErrorBoundary } from "@/components/status/ErrorBoundary";
import { useChatStream } from "@/features/chat/hooks";
import { AdminBillingBanner } from "@/features/billing/components/AdminBillingBanner";

// `<Providers>` has to wrap this gate rather than the other way round —
// AdminGate calls hooks (useTranslations, useChatStream, ...) that need to
// be a *descendant* of I18nProvider/QueryClientProvider, not their own
// ancestor.
export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <Providers>
      <AdminGate>{children}</AdminGate>
    </Providers>
  );
}

// /admin/pending is reachable by any ROLE_USER, not just trainers — it's the
// waiting room a trainer request lands in before the role is granted
// (docs/landing_page/66-trainer-billing-web-plan.md §2, D-T1). It also skips
// the trainer chrome below (AppShell's trainer config assumes a trainer's
// nav items).
const PENDING_PATH = "/admin/pending";

function AdminGate({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const isPendingRoute = pathname === PENDING_PATH;
  const { user, isLoading, initialize, logout } = useSessionStore();
  const admin = useTranslations("admin");

  // Held open for the whole trainer shell rather than only on /admin/chat, so
  // the sidebar's unread badge stays live while the trainer works elsewhere.
  useChatStream(!!user?.roles.includes("ROLE_TRAINER"));

  useEffect(() => {
    initialize();
  }, [initialize]);

  useEffect(() => {
    if (isLoading) return;
    if (!user) {
      router.push("/login");
      return;
    }
    if (!user.roles.includes("ROLE_TRAINER") && !isPendingRoute) {
      router.push("/dashboard");
    }
  }, [isLoading, user, router, isPendingRoute]);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-bg">
        <span aria-hidden="true"
          className="material-symbols-rounded text-4xl animate-pulse"
          style={{ color: "var(--role)" }}
        >
          eco
        </span>
      </div>
    );
  }

  if (!user) return null;
  if (!user.roles.includes("ROLE_TRAINER") && !isPendingRoute) return null;

  if (isPendingRoute) {
    // No sidebar/chrome — a full-bleed waiting screen, not a trainer nav page.
    return <ErrorBoundary>{children}</ErrorBoundary>;
  }

  return (
    <AppShell
      user={user}
      onLogout={logout}
      groups={TRAINER_NAV_GROUPS}
      bottomNavItems={TRAINER_NAV_ITEMS}
      moreSheetItems={TRAINER_MORE_SHEET_ITEMS}
      roleBadge={{ icon: "fitness_center", label: admin("chip") }}
      roleRing="trainer"
      showSettingsRow={false}
      trainerPrefs
      extraContent={<AdminBillingBanner />}
    >
      <ErrorBoundary>{children}</ErrorBoundary>
    </AppShell>
  );
}
