"use client";

import { useEffect, type ButtonHTMLAttributes } from "react";
import { Icon } from "./Icon";

/** The FAB's height plus the gap above it, in px — what the shell must leave clear beneath its toast and content. */
const FAB_CLEARANCE_PX = 72;

export interface FabProps extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, "children"> {
  icon?: string;
  /** The visible label ("Étel") — an extended FAB, never an unlabelled circle. */
  label: string;
}

/**
 * The phone's one primary action (W2.12, D-W0.22's FAB slot): an extended 56 px primary pill, bottom right,
 * floating above the bottom nav (whose top edge is 80 px up) and below every overlay. It exists only under
 * 768 px. While mounted it publishes `--fab-clearance` on the root, which the shell adds to the content's
 * bottom padding (so the last row can scroll clear of it) and the toast adds to its offset (so "Snack törölve ·
 * Visszavonás" sits above it, not behind it).
 */
export function Fab({ icon = "add", label, className, style, ...rest }: FabProps) {
  useEffect(() => {
    const root = document.documentElement;
    root.style.setProperty("--fab-clearance", `${FAB_CLEARANCE_PX}px`);
    return () => {
      root.style.removeProperty("--fab-clearance");
    };
  }, []);

  return (
    <button
      type="button"
      data-testid="fab"
      className={["lifey-button md:hidden fixed right-4 z-30 inline-flex h-14 items-center justify-center gap-2 pl-4 pr-5 type-button", className]
        .filter(Boolean)
        .join(" ")}
      style={{
        bottom: "calc(env(safe-area-inset-bottom) + 96px)",
        borderRadius: "var(--r-pill)",
        background: "var(--primary)",
        color: "var(--on-primary)",
        boxShadow: "var(--e3)",
        ...style,
      }}
      {...rest}
    >
      <Icon name={icon} size={24} />
      {label}
    </button>
  );
}
