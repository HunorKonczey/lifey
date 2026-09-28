"use client";

import { useCallback, useEffect, useState } from "react";

const STORAGE_KEY = "lifey-sidebar-collapsed";
const COLLAPSE_BELOW = 1280;

function readStored(): boolean | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw === "true") return true;
    if (raw === "false") return false;
  } catch {
    // ignore storage errors
  }
  return null;
}

function writeStored(collapsed: boolean) {
  try {
    localStorage.setItem(STORAGE_KEY, String(collapsed));
  } catch {
    // ignore storage errors
  }
}

/**
 * DS-02's rail collapse state (D-W0.20): persisted per device, defaults to
 * collapsed at 1024-1279px and open at >=1280px when nothing is stored yet.
 * Starts `false` (matching the SSR render) and corrects itself once after
 * mount — reading `window.innerWidth` in the initializer would hydrate to a
 * different value than the server rendered, the same mismatch fixed in
 * `useMediaQuery`. `[` toggles it whenever no field has focus.
 */
export function useSidebarState() {
  const [collapsed, setCollapsedState] = useState(false);

  useEffect(() => {
    const stored = readStored();
    // eslint-disable-next-line react-hooks/set-state-in-effect -- one-time mount correction, not a sync loop
    setCollapsedState(stored !== null ? stored : window.innerWidth < COLLAPSE_BELOW);
  }, []);

  const setCollapsed = useCallback((value: boolean) => {
    setCollapsedState(value);
    writeStored(value);
  }, []);

  const toggle = useCallback(() => {
    setCollapsedState((c) => {
      const next = !c;
      writeStored(next);
      return next;
    });
  }, []);

  useEffect(() => {
    function handleKey(e: KeyboardEvent) {
      if (e.key !== "[") return;
      const target = e.target as HTMLElement;
      if (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable) return;
      e.preventDefault();
      toggle();
    }
    document.addEventListener("keydown", handleKey);
    return () => document.removeEventListener("keydown", handleKey);
  }, [toggle]);

  return { collapsed, setCollapsed, toggle };
}
