import type { HTMLAttributes, KeyboardEvent, ReactNode } from "react";

export type CardVariant = "card" | "hero" | "nested";

export interface CardProps extends HTMLAttributes<HTMLDivElement> {
  variant?: CardVariant;
  /** Hover tone + pointer cursor + a 0.98 press scale, keyboard-focusable
   *  and Enter/Space-activated — for a card that is itself the click target
   *  (never stack this with buttons inside it that need their own separate
   *  hit target semantics). */
  interactive?: boolean;
  children: ReactNode;
}

// `, var(--shadow-focus)` on every variant (including "no shadow" as the
// neutral placeholder, not the `none` keyword) — see globals.css's
// `--shadow-focus` comment: an inline box-shadow always wins over the
// `:focus-visible` stylesheet rule, so composing it in here is the only way
// an interactive card's focus ring survives its own e1/e2 shadow.
const VARIANT: Record<CardVariant, { radius: string; padding: string; background: string; shadow: string }> = {
  card: { radius: "var(--r-card)", padding: "p-4 md:p-5", background: "var(--card)", shadow: "var(--e1), var(--edge-card), var(--shadow-focus)" },
  hero: { radius: "var(--r-hero)", padding: "p-6", background: "var(--card)", shadow: "var(--e2), var(--edge-hero), var(--shadow-focus)" },
  nested: { radius: "calc(var(--r-card) - 16px)", padding: "p-4", background: "var(--nested)", shadow: "var(--shadow-focus)" },
};

/** The one card shape every surface uses (D-W0.7) — never a card inside a
 *  card (§0 principle 3): a `nested` card is how a row groups inside a
 *  `card`/`hero`, not another full card. */
export function Card({ variant = "card", interactive = false, className, style, onClick, onKeyDown, children, ...rest }: CardProps) {
  const v = VARIANT[variant];

  function handleKeyDown(e: KeyboardEvent<HTMLDivElement>) {
    onKeyDown?.(e);
    if (interactive && onClick && (e.key === "Enter" || e.key === " ")) {
      e.preventDefault();
      onClick(e as unknown as React.MouseEvent<HTMLDivElement>);
    }
  }

  return (
    <div
      role={interactive ? "button" : undefined}
      tabIndex={interactive ? 0 : undefined}
      onClick={onClick}
      onKeyDown={interactive ? handleKeyDown : onKeyDown}
      className={[v.padding, interactive ? "lifey-card-interactive" : "", className].filter(Boolean).join(" ")}
      style={{ borderRadius: v.radius, background: v.background, boxShadow: v.shadow, ...style }}
      {...rest}
    >
      {children}
    </div>
  );
}
