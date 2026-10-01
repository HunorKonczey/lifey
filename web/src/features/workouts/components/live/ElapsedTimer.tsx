"use client";

import { useEffect, useState } from "react";
import { formatDuration } from "../../cardioFormat";
import { elapsedSeconds } from "../../liveSession";

/**
 * The workout clock (W3.6): "24:18", "1:05:12". Derived from `startedAt` on every tick — a reload or a throttled
 * background tab cannot make it drift — and stopped at the session's own length once it is finished.
 */
export function ElapsedTimer({ startedAt, finishedAt, className }: { startedAt: string; finishedAt: string | null; className?: string }) {
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    if (finishedAt != null) return;
    const tick = () => setNow(Date.now());
    const id = setInterval(tick, 1000);
    // A tab coming back from the background catches up immediately instead of waiting up to a second.
    document.addEventListener("visibilitychange", tick);
    return () => {
      clearInterval(id);
      document.removeEventListener("visibilitychange", tick);
    };
  }, [finishedAt]);

  return (
    <time className={["tabular", className].filter(Boolean).join(" ")} dateTime={`PT${elapsedSeconds(startedAt, finishedAt, now)}S`}>
      {formatDuration(elapsedSeconds(startedAt, finishedAt, now))}
    </time>
  );
}
