"use client";

import { create } from "zustand";

export type ToastVariant = "default" | "success" | "error" | "warning";

export interface ToastRecord {
  id: string;
  message: string;
  variant: ToastVariant;
  onUndo?: () => void;
  /** Errors never auto-dismiss — a close button instead (D-W0.14). */
  sticky: boolean;
}

interface ToastState {
  toast: ToastRecord | null;
  show: (message: string, variant?: ToastVariant) => void;
  showUndo: (message: string, onUndo: () => void, onCommit: () => void) => void;
  dismiss: () => void;
  undo: () => void;
  pause: () => void;
  resume: () => void;
}

/** The toast's own lifetime, and the undo window `useUndoableDelete` (D-W0.16)
 * rides on — one bar drives both. */
export const TOAST_DURATION_MS = 6000;

let _counter = 0;
let timer: ReturnType<typeof setTimeout> | null = null;
let remainingMs = TOAST_DURATION_MS;
let startedAt = 0;
let paused = false;
let pendingCommit: (() => void) | null = null;

function clearTimer() {
  if (timer !== null) {
    clearTimeout(timer);
    timer = null;
  }
}

/**
 * Fires whatever commit is still pending, exactly once, and forgets it — a
 * replacing toast, an explicit dismiss, a route change, or `pagehide`
 * (D-W0.16) all funnel through here instead of each having their own flush
 * logic.
 */
function flush() {
  clearTimer();
  paused = false;
  const commit = pendingCommit;
  pendingCommit = null;
  commit?.();
}

function arm(durationMs: number) {
  paused = false;
  remainingMs = durationMs;
  startedAt = Date.now();
  timer = setTimeout(() => {
    timer = null;
    flush();
    useToast.setState({ toast: null });
  }, durationMs);
}

export const useToast = create<ToastState>((set, get) => ({
  toast: null,
  show: (message, variant = "default") => {
    flush(); // a new toast replaces the old one and flushes its pending delete
    const sticky = variant === "error";
    set({ toast: { id: String(++_counter), message, variant, sticky } });
    if (!sticky) arm(TOAST_DURATION_MS);
  },
  showUndo: (message, onUndo, onCommit) => {
    flush();
    pendingCommit = onCommit;
    set({ toast: { id: String(++_counter), message, variant: "default", onUndo, sticky: false } });
    arm(TOAST_DURATION_MS);
  },
  dismiss: () => {
    flush();
    set({ toast: null });
  },
  undo: () => {
    clearTimer();
    paused = false;
    pendingCommit = null;
    const onUndo = get().toast?.onUndo;
    set({ toast: null });
    onUndo?.();
  },
  pause: () => {
    const toast = get().toast;
    if (!toast || toast.sticky || paused || timer === null) return;
    clearTimeout(timer);
    timer = null;
    remainingMs -= Date.now() - startedAt;
    paused = true;
  },
  resume: () => {
    const toast = get().toast;
    if (!toast || toast.sticky || !paused) return;
    arm(Math.max(remainingMs, 0));
  },
}));
