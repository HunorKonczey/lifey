import type { ButtonHTMLAttributes } from "react";
import { Icon } from "./Icon";
import { Tooltip } from "./Tooltip";

export interface IconButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  icon: string;
  /** Required — becomes the tooltip text and the `aria-label` (D-W0.17): an
   *  icon-only button is never unlabelled. */
  label: string;
  /** Visual box, 32–40px (D-W0.7). Default 36. */
  size?: number;
  shortcut?: string;
  fill?: 0 | 1;
}

/**
 * An icon-only button — 32–40px visual, but with a ≥44px hit area under
 * 768px (D-W0.18: desktop icon buttons need only a ≥32px hit area, touch
 * needs ≥44px) and a mandatory tooltip/`aria-label` from `label`.
 */
export function IconButton({ icon, label, size = 36, shortcut, fill = 0, className, style, ...rest }: IconButtonProps) {
  return (
    <Tooltip label={label} shortcut={shortcut}>
      <button
        type="button"
        aria-label={label}
        className={[
          "lifey-button inline-flex items-center justify-center rounded-[var(--r-control)] min-w-11 min-h-11 md:min-w-8 md:min-h-8",
          className,
        ]
          .filter(Boolean)
          .join(" ")}
        style={{ width: size, height: size, background: "transparent", color: "var(--text)", ...style }}
        {...rest}
      >
        <Icon name={icon} size={Math.round(size * 0.55)} fill={fill} />
      </button>
    </Tooltip>
  );
}
