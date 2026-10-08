"use client";

import { useEffect } from "react";
import { ErrorState } from "@/components/status/ErrorState";

/**
 * The app's error boundary (W10.2): a render error in any route lands here instead of Next's bare page - the DS error state
 * with Retry (`reset` re-renders the segment) and the error digest behind "Details". It sits inside the root layout, so the
 * theme and the messages are available. Every route group's `error.tsx` re-exports it (there is no top-level `app/error.tsx`
 * any more — each group is its own root, LIF-142).
 */
export default function AppError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <div className="flex min-h-[60vh] items-center justify-center px-4 py-10" style={{ background: "var(--bg)" }}>
      <ErrorState onRetry={reset} code={error.digest} />
    </div>
  );
}
