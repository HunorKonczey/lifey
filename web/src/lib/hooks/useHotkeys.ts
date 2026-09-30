"use client";

import { useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import type { NavItemDef } from "@/components/shell/navConfig";
import { usePageShortcutsStore } from "./usePageShortcuts";

const CHORD_TIMEOUT_MS = 1000;

/** True when typing into this would eat the keystroke — a shortcut must
 *  never fire while it does (D-W0.17). Pure (tag name + flag, not a DOM
 *  node) so it's unit-testable without jsdom (D-W0.12: Vitest is node-only). */
export function isTypingTarget(tagName: string, isContentEditable: boolean): boolean {
  return tagName === "INPUT" || tagName === "TEXTAREA" || isContentEditable;
}

/** `Modal`/`Drawer` both lock body scroll while open (D-W0.12/15) — the
 *  cheapest reliable "something else owns focus/attention right now" read,
 *  without threading a second piece of global overlay state through every
 *  shortcut listener. Not unit-tested here (no DOM in the node test env);
 *  exercised instead by `e2e/ds/shortcuts.spec.ts`. */
export function isOverlaySuppressing(): boolean {
  return typeof document !== "undefined" && document.body.style.overflow === "hidden";
}

/** Resolves `G <letter>` to a route via the current role's own nav items —
 *  each already carries a `shortcut` letter (D-W0.20/22's `NavItemDef`) —
 *  pure, so the chord's resolution logic is unit-testable on its own. */
export function matchGoTo(letter: string, items: Pick<NavItemDef, "shortcut" | "href">[]): string | null {
  const match = items.find((i) => i.shortcut.toLowerCase() === letter.toLowerCase());
  return match?.href ?? null;
}

/** The `G` chord's 1s "waiting for the second key" window (D-W0.17) — a
 *  framework-free timer state machine, not tangled into the DOM-listening
 *  hook below, so its timeout behaviour is unit-testable with fake timers
 *  in the node test environment (no jsdom needed, D-W0.12). */
export function createChordTracker(timeoutMs = CHORD_TIMEOUT_MS) {
  let active = false;
  let timer: ReturnType<typeof setTimeout> | null = null;

  function clear() {
    active = false;
    if (timer) clearTimeout(timer);
    timer = null;
  }

  return {
    get active() {
      return active;
    },
    start() {
      active = true;
      if (timer) clearTimeout(timer);
      timer = setTimeout(clear, timeoutMs);
    },
    consume: clear,
  };
}

export interface UseHotkeysOptions {
  /** The current role's flat nav items, for `G <letter>` (D-W0.17). */
  goToItems: Pick<NavItemDef, "shortcut" | "href">[];
  onHelp: () => void;
  /** Suppresses everything, e.g. while the help overlay itself is open. */
  suppressed?: boolean;
}

/**
 * DS-06's global shortcut layer (D-W0.17): `G <letter>` go-to (1s chord
 * timeout), `?` help, and reads whatever the current page registered via
 * `usePageShortcuts` for `N`/`/`. `[` (sidebar collapse) and `←`/`→`/`T`
 * (date stepper) stay as their own listeners from W0.20/21 — already
 * correct and tested — but both gained the same `isOverlaySuppressing`
 * guard this step so every shortcut agrees on "never while a modal owns
 * focus."
 */
export function useHotkeys({ goToItems, onHelp, suppressed }: UseHotkeysOptions) {
  const router = useRouter();
  const chordRef = useRef(createChordTracker());

  useEffect(() => {
    const chord = chordRef.current;

    function handleKey(e: KeyboardEvent) {
      const target = e.target as HTMLElement | null;
      if (target && isTypingTarget(target.tagName, target.isContentEditable)) return;
      if (suppressed || isOverlaySuppressing()) return;

      if (chord.active) {
        const key = e.key;
        chord.consume();
        const href = matchGoTo(key, goToItems);
        if (href) {
          e.preventDefault();
          router.push(href);
        }
        return;
      }

      if (e.key === "?") {
        e.preventDefault();
        onHelp();
        return;
      }
      if (e.key.toLowerCase() === "g" && !e.metaKey && !e.ctrlKey && !e.altKey) {
        chord.start();
        return;
      }
      if (e.key.toLowerCase() === "n") {
        const onNew = usePageShortcutsStore.getState().onNew;
        if (onNew) {
          e.preventDefault();
          onNew();
        }
        return;
      }
      if (e.key === "/") {
        const searchRef = usePageShortcutsStore.getState().searchRef;
        if (searchRef?.current) {
          e.preventDefault();
          searchRef.current.focus();
        }
      }
    }

    document.addEventListener("keydown", handleKey);
    return () => {
      document.removeEventListener("keydown", handleKey);
      chord.consume();
    };
  }, [goToItems, onHelp, suppressed, router]);
}
