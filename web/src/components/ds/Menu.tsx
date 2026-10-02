"use client";

import { useEffect, useRef, type RefObject } from "react";
import { useRovingFocus } from "@/lib/a11y/useRovingFocus";
import { Icon } from "./Icon";
import { Popover } from "./Popover";

export interface MenuItemDef {
  label: string;
  icon?: string;
  shortcut?: string;
  onSelect: () => void;
  /** Heart-coloured, ends the label with "…" — a confirmation follows
   *  (D-W0.15). Always the last item. */
  destructive?: boolean;
}

export interface MenuProps {
  open: boolean;
  onClose: () => void;
  anchorRef: RefObject<HTMLElement | null>;
  items: MenuItemDef[];
  width?: number;
  className?: string;
}

/** A row/toolbar "⋯" menu (D-W0.11) — arrow keys move the selection with
 *  letter typeahead, Enter/Space activates, Esc closes and returns focus. */
export function Menu({ open, onClose, anchorRef, items, width = 220, className }: MenuProps) {
  const itemRefs = useRef<(HTMLButtonElement | null)[]>([]);
  const { activeIndex, setActiveIndex, handleKeyDown } = useRovingFocus(items.length);

  useEffect(() => {
    if (!open) return;
    setActiveIndex(0);
    const raf = requestAnimationFrame(() => itemRefs.current[0]?.focus());
    return () => cancelAnimationFrame(raf);
  }, [open, setActiveIndex]);

  useEffect(() => {
    if (open) itemRefs.current[activeIndex]?.focus();
  }, [activeIndex, open]);

  function select(index: number) {
    items[index]?.onSelect();
    onClose();
  }

  return (
    <Popover open={open} onClose={onClose} anchorRef={anchorRef} width={width} className={className}>
      <div
        role="menu"
        className="py-1.5"
        onKeyDown={(e) => handleKeyDown(e, items.map((i) => i.label), select)}
      >
        {items.map((item, i) => (
          <button
            key={item.label}
            ref={(el) => {
              itemRefs.current[i] = el;
            }}
            type="button"
            role="menuitem"
            tabIndex={i === activeIndex ? 0 : -1}
            onClick={() => select(i)}
            className="lifey-button flex w-full items-center gap-2.5 px-3 h-10 type-body-s text-left"
            style={{ background: "transparent", color: item.destructive ? "var(--heart)" : "var(--text)" }}
          >
            {item.icon && <Icon name={item.icon} size={18} color={item.destructive ? "var(--heart)" : "var(--text-2)"} />}
            <span className="flex-1 truncate">
              {item.label}
              {item.destructive ? "…" : ""}
            </span>
            {item.shortcut && (
              <kbd className="type-label" style={{ color: "var(--text-3)" }}>
                {item.shortcut}
              </kbd>
            )}
          </button>
        ))}
      </div>
    </Popover>
  );
}
