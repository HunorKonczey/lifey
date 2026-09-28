"use client";

import { useRef, useState, type KeyboardEvent } from "react";
import { Icon } from "./Icon";
import { Menu, type MenuItemDef } from "./Menu";

export interface RowMenuButtonProps {
  items: MenuItemDef[];
  label?: string;
}

/** The table/list "⋯" (D-W0.11) — 32px, opens on click and `Shift+F10`, the
 *  standard "context menu" keyboard shortcut for a focused row. */
export function RowMenuButton({ items, label = "More actions" }: RowMenuButtonProps) {
  const [open, setOpen] = useState(false);
  const buttonRef = useRef<HTMLButtonElement>(null);

  function handleKeyDown(e: KeyboardEvent<HTMLButtonElement>) {
    if (e.key === "F10" && e.shiftKey) {
      e.preventDefault();
      setOpen(true);
    }
  }

  return (
    <>
      <button
        ref={buttonRef}
        type="button"
        aria-label={label}
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => setOpen(true)}
        onKeyDown={handleKeyDown}
        className="lifey-button inline-flex items-center justify-center rounded-[var(--r-control)]"
        style={{ width: 32, height: 32, background: "transparent", color: "var(--text-2)" }}
      >
        <Icon name="more_horiz" size={18} />
      </button>
      <Menu open={open} onClose={() => setOpen(false)} anchorRef={buttonRef} items={items} />
    </>
  );
}
