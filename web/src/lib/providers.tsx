"use client";

import { useEffect } from "react";
import { QueryClientProvider } from "@tanstack/react-query";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";
import { Toaster } from "@/components/ui/Toaster";
import { useSessionStore } from "@/features/auth/store";
import { loadClientConfig } from "@/lib/api/client-config";
import { useLocale } from "@/lib/hooks/useLocale";
import { I18nProvider } from "@/lib/i18n/provider";
import { queryClient } from "@/lib/queryClient";

export function Providers({ children }: { children: React.ReactNode }) {
  const { locale, detectBrowserLocale } = useLocale();
  const userId = useSessionStore((s) => s.user?.id ?? null);

  // Runs after the initial (SSR-matching) render, so it can't cause a
  // hydration mismatch — see useLocale's comment for why the store can't
  // read navigator.language up front.
  useEffect(() => {
    detectBrowserLocale();
  }, [detectBrowserLocale]);

  // Where the chat service lives (docs/chat/44-chat-service-extraction-plan.md
  // §7.1). Fire-and-forget by design: it seeds from a cached value first and
  // never throws, so nothing below it waits on the network or breaks if the
  // call fails.
  //
  // Keyed on the signed-in user rather than run once on mount, because
  // `/client-config` is authenticated: the mount-time call happens before
  // anyone has signed in and can only ever 401. Re-asking when a session
  // appears is what actually resolves the chat's host — and re-asking when the
  // account changes keeps a second user on this tab from inheriting the first
  // one's answer.
  useEffect(() => {
    void loadClientConfig();
  }, [userId]);

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
