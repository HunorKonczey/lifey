"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { Providers } from "@/lib/providers";
import { useSessionStore } from "@/features/auth/store";
import { settingsApi } from "@/features/settings/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useLocale } from "@/lib/hooks/useLocale";
import { useDateStore } from "@/lib/hooks/useDateStore";
import { AppShell } from "@/components/shell/AppShell";
import { ErrorBoundary } from "@/components/status/ErrorBoundary";

// `<Providers>` has to wrap this gate rather than the other way round —
// AppGate calls hooks (useQuery, useLocale, ...) that need to be a
// *descendant* of QueryClientProvider/I18nProvider, not their own ancestor.
export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <Providers>
      <AppGate>{children}</AppGate>
    </Providers>
  );
}

// Auth guard + locale/date sync — renamed from `AppShell` (D-W0.20) so that
// name is free for the new `src/components/shell/AppShell.tsx`, which now
// owns the actual chrome (sidebar/top bar) this used to render inline.
function AppGate({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const { user, isLoading, initialize, logout } = useSessionStore();
  const { setLanguage } = useLocale();

  const { data: settings } = useQuery({
    queryKey: queryKeys.settings.all(),
    queryFn: settingsApi.get,
    enabled: !!user,
  });

  useEffect(() => {
    if (settings?.language) setLanguage(settings.language);
  }, [settings?.language, setLanguage]);

  useEffect(() => {
    initialize();
  }, [initialize]);

  // Rolls the date-store's "today" forward when the tab regains focus —
  // otherwise a tab left open overnight keeps filtering fresh data against
  // yesterday's date until the user manually clicks the "today" pill.
  useEffect(() => {
    const handler = () => {
      if (document.visibilityState === "visible") useDateStore.getState().syncToday();
    };
    document.addEventListener("visibilitychange", handler);
    window.addEventListener("focus", handler);
    return () => {
      document.removeEventListener("visibilitychange", handler);
      window.removeEventListener("focus", handler);
    };
  }, []);

  // Redirect to login whenever there is no authenticated user (covers both
  // a failed initialize() and an explicit logout()).
  useEffect(() => {
    if (!isLoading && !user) {
      router.push("/login");
    }
  }, [isLoading, user, router]);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-bg">
        <span
          className="material-symbols-rounded text-4xl animate-pulse"
          style={{ color: "var(--primary)" }}
        >
          eco
        </span>
      </div>
    );
  }

  if (!user) return null;

  return (
    <AppShell user={user} onLogout={logout}>
      <ErrorBoundary>{children}</ErrorBoundary>
    </AppShell>
  );
}
