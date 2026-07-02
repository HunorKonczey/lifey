"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";
import { useState } from "react";
import { Toaster } from "@/components/ui/Toaster";
import { ApiError } from "@/lib/api/client";
import { useLocale } from "@/lib/hooks/useLocale";
import { I18nProvider } from "@/lib/i18n/provider";

export function Providers({ children }: { children: React.ReactNode }) {
  const { locale } = useLocale();
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 60_000,
            gcTime: 5 * 60_000,
            retry: (failureCount, error: unknown) => {
              if (
                error instanceof ApiError &&
                error.status < 500
              ) {
                return false;
              }
              return failureCount < 2;
            },
          },
        },
      }),
  );

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
