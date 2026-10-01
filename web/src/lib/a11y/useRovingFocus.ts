"use client";

import { useRef, useState, type KeyboardEvent } from "react";

export interface RovingFocus {
  activeIndex: number;
  setActiveIndex: (index: number) => void;
  /** Wire this to the group's `onKeyDown`. Calls `onSelect` for
   *  Enter/Space, and does letter typeahead against `labels` (D-W0.11's
   *  `e2e/ds/menu.spec.ts` — "arrow navigation, typeahead"). */
  handleKeyDown: (e: KeyboardEvent, labels: string[], onSelect?: (index: number) => void) => void;
}

const TYPEAHEAD_RESET_MS = 500;

/** Arrow-key navigation (with optional letter typeahead) over a flat list
 *  of items — the roving-tabindex pattern behind Menu, and reusable by any
 *  later list/grid that needs the same arrow + typeahead behaviour. */
export function useRovingFocus(itemCount: number, loop = true): RovingFocus {
  const [activeIndex, setActiveIndex] = useState(0);
  const typeaheadRef = useRef({ buffer: "", timer: 0 as unknown as ReturnType<typeof setTimeout> });

  function move(delta: number) {
    setActiveIndex((i) => {
      const next = i + delta;
      if (loop) return (next + itemCount) % itemCount;
      return Math.min(itemCount - 1, Math.max(0, next));
    });
  }

  function handleKeyDown(e: KeyboardEvent, labels: string[], onSelect?: (index: number) => void) {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      move(1);
      return;
    }
    if (e.key === "ArrowUp") {
      e.preventDefault();
      move(-1);
      return;
    }
    if (e.key === "Home") {
      e.preventDefault();
      setActiveIndex(0);
      return;
    }
    if (e.key === "End") {
      e.preventDefault();
      setActiveIndex(itemCount - 1);
      return;
    }
    if ((e.key === "Enter" || e.key === " ") && onSelect) {
      e.preventDefault();
      onSelect(activeIndex);
      return;
    }
    if (e.key.length === 1 && /[\p{L}\p{N}]/u.test(e.key)) {
      const state = typeaheadRef.current;
      clearTimeout(state.timer);
      state.buffer += e.key.toLowerCase();
      const match = labels.findIndex((label) => label.toLowerCase().startsWith(state.buffer));
      if (match !== -1) setActiveIndex(match);
      state.timer = setTimeout(() => {
        state.buffer = "";
      }, TYPEAHEAD_RESET_MS);
    }
  }

  return { activeIndex, setActiveIndex, handleKeyDown };
}
