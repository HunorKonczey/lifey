import { useEffect, type ReactNode } from "react";
import { create } from "zustand";

interface TopBarSlotState {
  /** Replaces the top bar's centre (normally the date stepper on dated pages) — the weight page's range switcher. */
  centre: ReactNode | null;
}

export const useTopBarSlotStore = create<TopBarSlotState>(() => ({ centre: null }));

/**
 * Puts `node` in the top bar's centre for as long as the calling page is mounted (W4.2). Memoise the node
 * (`useMemo`) — a new element on every render would re-register on every render. Clears itself on unmount so the
 * next page does not inherit it; `null` leaves the centre to the route's own default.
 */
export function useTopBarCentre(node: ReactNode | null) {
  useEffect(() => {
    useTopBarSlotStore.setState({ centre: node });
    return () => useTopBarSlotStore.setState({ centre: null });
  }, [node]);
}
