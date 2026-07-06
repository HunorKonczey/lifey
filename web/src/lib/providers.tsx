"use client";

import { useEffect } from "react";
import { QueryClientProvider } from "@tanstack/react-query";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";
import { Toaster } from "@/components/ui/Toaster";
import { useLocale } from "@/lib/hooks/useLocale";
import { I18nProvider } from "@/lib/i18n/provider";
import { queryClient } from "@/lib/queryClient";

export function Providers({ children }: { children: React.ReactNode }) {
  const { locale, detectBrowserLocale } = useLocale();

  // Runs after the initial (SSR-matching) render, so it can't cause a
  // hydration mismatch — see useLocale's comment for why the store can't
  // read navigator.language up front.
  useEffect(() => {
    detectBrowserLocale();
  }, [detectBrowserLocale]);

  return (
    <QueryClientProvider client={queryClient}>
      <I18nProvider locale={locale}>
        {children}
        <Toaster />
      </I18nProvider>
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
}
