import { useEffect } from "react";
import { create } from "zustand";
import type { RefObject } from "react";

interface PageShortcutsState {
  onNew?: () => void;
  /** Shown in the `?` help overlay's "This page" section next to `N` — e.g. "Add a meal". */
  newLabel?: string;
  searchRef?: RefObject<HTMLElement | null>;
}

/** The current page's `N`/`/` targets (D-W0.17) — a page can't provide
 *  context *up* to the shell that owns the global key listener, so this is
 *  a tiny shared store instead: `usePageShortcuts` (called by the page)
 *  writes to it, `useHotkeys` (called once by `AppShell`) reads it. */
export const usePageShortcutsStore = create<PageShortcutsState>(() => ({}));

/**
 * Registers this page's "new entry" action and/or search field for the
 * shell's `N`/`/` shortcuts (D-W0.17). Clears itself on unmount so the next
 * page navigated to doesn't inherit a stale handler.
 */
export function usePageShortcuts(value: PageShortcutsState) {
  useEffect(() => {
    usePageShortcutsStore.setState(value);
    return () => usePageShortcutsStore.setState({ onNew: undefined, newLabel: undefined, searchRef: undefined });
    // eslint-disable-next-line react-hooks/exhaustive-deps -- re-registering on every render would fight the store's own state
  }, [value.onNew, value.newLabel, value.searchRef]);
}
