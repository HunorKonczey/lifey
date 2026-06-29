"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { useSessionStore } from "@/features/auth/store";
import { settingsApi } from "@/features/settings/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useLocale } from "@/lib/hooks/useLocale";
import { I18nProvider } from "@/lib/i18n/provider";
import { Sidebar } from "@/components/layout/Sidebar";
import { TopBar } from "@/components/layout/TopBar";
import { ErrorBoundary } from "@/components/status/ErrorBoundary";

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const { user, isLoading, initialize } = useSessionStore();
  const { locale, setLanguage } = useLocale();

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
    <I18nProvider locale={locale}>
      <div className="flex min-h-screen bg-bg">
        <Sidebar />
        <div className="flex flex-col flex-1 min-w-0">
          <TopBar />
          <main className="flex-1 p-6 overflow-auto">
            <ErrorBoundary>{children}</ErrorBoundary>
          </main>
        </div>
      </div>
    </I18nProvider>
  );
}
