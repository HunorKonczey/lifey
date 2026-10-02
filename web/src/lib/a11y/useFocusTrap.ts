"use client";

import { useEffect, type RefObject } from "react";

const FOCUSABLE_SELECTOR =
  'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])';

/**
 * Traps Tab/Shift+Tab inside `containerRef` while `active` (D-W0.12) —
 * initial focus goes to the element marked `data-autofocus` (the safe
 * button in `ConfirmModal`), else the first focusable element.
 */
export function useFocusTrap(active: boolean, containerRef: RefObject<HTMLElement | null>) {
  useEffect(() => {
    if (!active || !containerRef.current) return;
    const container = containerRef.current;

    function getFocusable(): HTMLElement[] {
      return Array.from(container.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR)).filter(
        (el) => el.offsetParent !== null,
      );
    }

    const autofocusEl = container.querySelector<HTMLElement>("[data-autofocus]");
    (autofocusEl ?? getFocusable()[0])?.focus();

    function handleKeyDown(e: KeyboardEvent) {
      // A field that already moved focus itself (e.g. the add-food search jumping to the quantity) has
      // handled this Tab — wrapping on top of that would undo it.
      if (e.key !== "Tab" || e.defaultPrevented) return;
      const focusable = getFocusable();
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    }

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [active, containerRef]);
}
