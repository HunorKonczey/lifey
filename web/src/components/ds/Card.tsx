import type { HTMLAttributes, ReactNode } from "react";

export type CardVariant = "card" | "hero" | "nested";

export interface CardProps extends HTMLAttributes<HTMLDivElement> {
  variant?: CardVariant;
  /** Hover tone + pointer cursor + a 0.98 press scale — for a card that is
   *  itself the click target (never stack this with buttons inside it that
   *  need their own separate hit target semantics). */
  interactive?: boolean;
  children: ReactNode;
}

const VARIANT: Record<CardVariant, { radius: string; padding: string; background: string; shadow: string }> = {
  card: { radius: "var(--r-card)", padding: "p-4 md:p-5", background: "var(--card)", shadow: "var(--e1), var(--edge-card)" },
  hero: { radius: "var(--r-hero)", padding: "p-6", background: "var(--card)", shadow: "var(--e2), var(--edge-hero)" },
  nested: { radius: "calc(var(--r-card) - 16px)", padding: "p-4", background: "var(--nested)", shadow: "none" },
};

/** The one card shape every surface uses (D-W0.7) — never a card inside a
 *  card (§0 principle 3): a `nested` card is how a row groups inside a
 *  `card`/`hero`, not another full card. */
export function Card({ variant = "card", interactive = false, className, style, children, ...rest }: CardProps) {
  const v = VARIANT[variant];
  return (
    <div
      className={[v.padding, interactive ? "lifey-card-interactive" : "", className].filter(Boolean).join(" ")}
      style={{ borderRadius: v.radius, background: v.background, boxShadow: v.shadow, ...style }}
      {...rest}
    >
      {children}
    </div>
  );
}
