/**
 * Material Symbols Rounded through one component (D-W0.10) — the FILL axis
 * (0 outline / 1 solid) is how "active nav item = filled icon" (DS-02)
 * becomes a single prop instead of a hand-written `font-variation-settings`
 * at every call site. The font itself is already loaded globally
 * (`app/layout.tsx`).
 *
 * Purely presentational by default (`aria-hidden`). Pass `label` only when
 * the icon stands alone with no adjacent visible text — an icon-only button
 * gets its label from `IconButton` (W0.8), not from this prop.
 */
export interface IconProps {
  name: string;
  /** 0 = outline (inactive), 1 = solid (active). Default 0. */
  fill?: 0 | 1;
  /** Pixel size — also drives the optical-size (`opsz`) axis. Default 24. */
  size?: number;
  /** Variable-font weight, 100–700. Default 400. */
  weight?: number;
  /** A CSS colour — omit to inherit `color` from the surrounding text. */
  color?: string;
  className?: string;
  /** Set only when the icon alone conveys meaning (no visible label beside it). */
  label?: string;
}

export function Icon({ name, fill = 0, size = 24, weight = 400, color, className, label }: IconProps) {
  return (
    <span
      className={["material-symbols-rounded select-none", className].filter(Boolean).join(" ")}
      style={{
        fontSize: size,
        lineHeight: 1,
        color,
        fontVariationSettings: `'FILL' ${fill}, 'wght' ${weight}, 'GRAD' 0, 'opsz' ${size}`,
      }}
      aria-hidden={label ? undefined : true}
      aria-label={label}
      role={label ? "img" : undefined}
    >
      {name}
    </span>
  );
}
