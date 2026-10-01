"use client";

import { useEffect, useState } from "react";

export interface ViewportBox {
  /** The visible height in px — shrinks when the on-screen keyboard opens. */
  height: number;
  /** How far the visible area has been pushed down inside the layout viewport (iOS scrolls it when the keyboard opens). */
  offsetTop: number;
}

/**
 * The visual viewport's height and offset, kept current while `active`. A phone's on-screen keyboard shrinks the *visual*
 * viewport, not the layout one, so a full-screen thread sized with it keeps its composer above the keyboard instead of
 * underneath it. `null` until measured (and during SSR) — the caller falls back to `100dvh`.
 */
export function useVisualViewport(active: boolean): ViewportBox | null {
  const [box, setBox] = useState<ViewportBox | null>(null);
  useEffect(() => {
    if (!active) return;
    const vv = window.visualViewport;
    if (!vv) return;
    const read = () => setBox({ height: Math.round(vv.height), offsetTop: Math.round(vv.offsetTop) });
    read();
    vv.addEventListener("resize", read);
    vv.addEventListener("scroll", read);
    return () => {
      vv.removeEventListener("resize", read);
      vv.removeEventListener("scroll", read);
    };
  }, [active]);
  return active ? box : null;
}
