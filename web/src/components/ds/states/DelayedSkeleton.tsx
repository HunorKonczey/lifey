"use client";

import { useEffect, useState, type ReactNode } from "react";

export interface DelayedSkeletonProps {
  /** ms before the skeleton appears — default 300 (D-W0.17): avoids a flash
   *  of loading UI for a request that resolves almost immediately. */
  delayMs?: number;
  /** Typically a `Skeleton`, shaped like the final layout so nothing shifts
   *  when the real content swaps in. */
  children: ReactNode;
}

/**
 * Renders `children` only once `delayMs` has elapsed (D-W0.17) — nothing
 * before that, not even a flash. The delay itself isn't a motion effect (it
 * doesn't shorten under reduced motion); `Skeleton`'s own pulse animation is
 * what goes static there.
 */
export function DelayedSkeleton({ delayMs = 300, children }: DelayedSkeletonProps) {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const timer = setTimeout(() => setVisible(true), delayMs);
    return () => clearTimeout(timer);
    // delayMs is read once — this shows the skeleton at most once per mount,
    // not every time a caller happens to pass a new delayMs value.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (!visible) return null;
  return <>{children}</>;
}
