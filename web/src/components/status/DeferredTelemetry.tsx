"use client";

import dynamic from "next/dynamic";
import { useEffect, useState } from "react";

// Vercel's two scripts are not needed to render or hydrate anything, so they
// are code-split out of the root layout's first-load bundle and only fetched
// once the browser is idle (docs/landing_page/72 W7 / F6). `ssr: false` is
// allowed here because this is a client component.
const SpeedInsights = dynamic(() => import("@vercel/speed-insights/next").then((m) => m.SpeedInsights), {
  ssr: false,
});
const Analytics = dynamic(() => import("@vercel/analytics/next").then((m) => m.Analytics), { ssr: false });

/** Mounts Vercel Speed Insights + Analytics after first paint, when the main thread is idle. */
export function DeferredTelemetry() {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const start = () => setReady(true);
    if (typeof window.requestIdleCallback === "function") {
      const id = window.requestIdleCallback(start, { timeout: 4000 });
      return () => window.cancelIdleCallback(id);
    }
    // Safari has no requestIdleCallback.
    const id = window.setTimeout(start, 2000);
    return () => window.clearTimeout(id);
  }, []);

  if (!ready) return null;
  return (
    <>
      <SpeedInsights />
      <Analytics />
    </>
  );
}
