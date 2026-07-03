import { QueryClient } from "@tanstack/react-query";
import { ApiError } from "@/lib/api/client";

/**
 * Single shared QueryClient instance. Needs to be a module-level singleton
 * (rather than created inside <Providers>) so code outside the React tree —
 * e.g. the auth store's logout/login handlers — can clear it directly.
 */
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60_000,
      gcTime: 5 * 60_000,
      retry: (failureCount, error: unknown) => {
        if (error instanceof ApiError && error.status < 500) {
          return false;
        }
        return failureCount < 2;
      },
    },
  },
});
