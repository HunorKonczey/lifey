"use client";

import { useState, type KeyboardEvent } from "react";

export interface TableKeyboard {
  activeIndex: number;
  setActiveIndex: (index: number) => void;
  /** Wire to the table body's `onKeyDown` (D-W0.15) — ↑/↓ moves the active
   *  row, Enter opens it, `Shift+F10` opens its row menu. */
  handleKeyDown: (e: KeyboardEvent, onOpen?: () => void, onRowMenu?: () => void) => void;
}

export function useTableKeyboard(rowCount: number): TableKeyboard {
  const [activeIndex, setActiveIndex] = useState(0);

  function handleKeyDown(e: KeyboardEvent, onOpen?: () => void, onRowMenu?: () => void) {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setActiveIndex((i) => Math.min(i + 1, Math.max(rowCount - 1, 0)));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setActiveIndex((i) => Math.max(i - 1, 0));
    } else if (e.key === "Enter") {
      if (!onOpen) return;
      e.preventDefault();
      onOpen();
    } else if (e.key === "F10" && e.shiftKey) {
      if (!onRowMenu) return;
      e.preventDefault();
      onRowMenu();
    }
  }

  return { activeIndex, setActiveIndex, handleKeyDown };
}
