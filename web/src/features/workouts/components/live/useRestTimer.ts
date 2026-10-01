"use client";

import { useCallback, useEffect, useState } from "react";
import { IDLE, REST_STEP_SECONDS, adjustRest, skipRest, startRest, togglePause, type RestState } from "../../restTimer";

/**
 * The live logger's rest countdown (W3.8): the state machine of `restTimer.ts` plus a `now` that re-reads the
 * clock four times a second while it runs (and on `visibilitychange`, so a tab coming back shows the truth at
 * once). The countdown itself is derived from timestamps, so the interval only drives re-rendering.
 */
export function useRestTimer() {
  const [state, setState] = useState<RestState>(IDLE);
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    if (state.status !== "running") return;
    const tick = () => setNow(Date.now());
    const id = setInterval(tick, 250);
    document.addEventListener("visibilitychange", tick);
    return () => {
      clearInterval(id);
      document.removeEventListener("visibilitychange", tick);
    };
  }, [state.status]);

  return {
    state,
    now,
    start: useCallback((seconds: number, nextSet: number | null) => {
      const at = Date.now();
      setNow(at);
      setState(startRest(at, seconds, nextSet));
    }, []),
    adjust: useCallback((deltaSeconds: number) => setState((s) => adjustRest(s, Date.now(), deltaSeconds)), []),
    pauseResume: useCallback(() => setState((s) => togglePause(s, Date.now())), []),
    skip: useCallback(() => setState(skipRest()), []),
    step: REST_STEP_SECONDS,
  };
}
