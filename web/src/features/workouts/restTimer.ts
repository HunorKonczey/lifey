/**
 * The rest countdown as a pure state machine (W3.8). Nothing here counts ticks: a running timer stores the
 * moment it ends, a paused one the milliseconds it had left, so the display is a function of `now` — a
 * throttled background tab or a reload-free long pause cannot make it drift.
 */
export type RestState =
  | { status: "idle" }
  | { status: "running"; totalMs: number; endsAt: number; nextSet: number | null }
  | { status: "paused"; totalMs: number; remainingMs: number; nextSet: number | null };

export const IDLE: RestState = { status: "idle" };

/** The −15 s / +15 s step. */
export const REST_STEP_SECONDS = 15;
/** The last seconds turn the colour and pulse. */
export const REST_URGENT_SECONDS = 5;

/** A fresh countdown of `seconds`, announcing which set comes after it (`nextSet`, 1-based, or null). */
export function startRest(now: number, seconds: number, nextSet: number | null): RestState {
  const totalMs = Math.max(0, Math.round(seconds)) * 1000;
  return { status: "running", totalMs, endsAt: now + totalMs, nextSet };
}

/** Milliseconds left, never negative. */
export function remainingMs(state: RestState, now: number): number {
  if (state.status === "idle") return 0;
  return state.status === "paused" ? state.remainingMs : Math.max(0, state.endsAt - now);
}

/** Whole seconds to show: rounded up, so "0:01" is shown until the very end and "0:00" means done. */
export function remainingSeconds(state: RestState, now: number): number {
  return Math.ceil(remainingMs(state, now) / 1000);
}

export function isFinished(state: RestState, now: number): boolean {
  return state.status === "running" && remainingMs(state, now) === 0;
}

export function isUrgent(state: RestState, now: number): boolean {
  const s = remainingSeconds(state, now);
  return state.status === "running" && s > 0 && s <= REST_URGENT_SECONDS;
}

/** Fraction of the rest still to go, 1 → 0 — the draining bar. */
export function remainingFraction(state: RestState, now: number): number {
  if (state.status === "idle" || state.totalMs === 0) return 0;
  return Math.min(1, remainingMs(state, now) / state.totalMs);
}

/** ±15 s (or any delta): moves the end, never below zero; the "of 2:00" total grows with it so the bar stays honest. */
export function adjustRest(state: RestState, now: number, deltaSeconds: number): RestState {
  if (state.status === "idle") return state;
  const deltaMs = deltaSeconds * 1000;
  const left = Math.max(0, remainingMs(state, now) + deltaMs);
  const totalMs = Math.max(state.totalMs, left);
  return state.status === "paused"
    ? { ...state, remainingMs: left, totalMs }
    : { ...state, endsAt: now + left, totalMs };
}

/** Space: pause a running countdown, resume a paused one; a finished or idle one stays as it is. */
export function togglePause(state: RestState, now: number): RestState {
  if (state.status === "running") {
    const left = remainingMs(state, now);
    return left === 0 ? state : { status: "paused", totalMs: state.totalMs, remainingMs: left, nextSet: state.nextSet };
  }
  if (state.status === "paused") {
    return { status: "running", totalMs: state.totalMs, endsAt: now + state.remainingMs, nextSet: state.nextSet };
  }
  return state;
}

/** "Kihagyás". */
export function skipRest(): RestState {
  return IDLE;
}

/**
 * Seconds of rest after a set of an exercise: the exercise's own, else the user's default, else 90 (the
 * backend's column default). Never below 5 s and never above 15 min, so a stray 0 cannot fire and vanish.
 */
export function restSecondsFor(exerciseRest: number | null | undefined, defaultRest: number | null | undefined): number {
  const raw = exerciseRest ?? defaultRest ?? 90;
  return Math.min(900, Math.max(5, raw));
}
