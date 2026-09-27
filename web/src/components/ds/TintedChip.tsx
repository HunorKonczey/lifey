import { Icon } from "./Icon";

export type TintedChipSize = "small" | "medium";

export interface TintedChipProps {
  label: string;
  /** A CSS colour, almost always a metric variable — `var(--m-protein)` etc.
   *  Pass the theme's own token, never a hard-coded hex (D-W0.4's tint rule
   *  only holds for the metric colours the contrast test guards). */
  color: string;
  icon?: string;
  /** 26px — inside rows and tiles. 32px — standalone. */
  size?: TintedChipSize;
  /** What a screen reader says instead of the visible label. */
  semanticsLabel?: string;
  className?: string;
}

/**
 * The one place a tinted chip is built (D-W0.7, mobile D-R0.4 parity): the
 * background is `color` at 16% in dark / 12% in light (`--chip-tint`), the
 * text and icon are `color` itself — so the contrast rule can't be broken at
 * a call site the way a hand-rolled `background: color + "33"` could.
 */
export function TintedChip({ label, color, icon, size = "small", semanticsLabel, className }: TintedChipProps) {
  const small = size === "small";
  return (
    <span
      aria-label={semanticsLabel}
      className={["inline-flex items-center gap-1 rounded-[var(--r-pill)]", className].filter(Boolean).join(" ")}
      style={{
        minHeight: small ? 26 : 32,
        padding: `4px ${small ? 10 : 12}px`,
        background: `color-mix(in srgb, ${color} var(--chip-tint), transparent)`,
        color,
      }}
    >
      {icon && <Icon name={icon} size={small ? 13 : 15} />}
      <span
        className="tabular"
        style={{ fontSize: small ? 12 : 13, lineHeight: "16px", fontWeight: 700 }}
        aria-hidden={semanticsLabel ? true : undefined}
      >
        {label}
      </span>
    </span>
  );
}
