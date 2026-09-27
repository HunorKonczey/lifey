import type { ButtonHTMLAttributes } from "react";

export type ButtonVariant = "primary" | "secondary" | "tonal" | "ghost" | "danger";
export type ButtonSize = "default" | "auth" | "cta";

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  fullWidth?: boolean;
}

const HEIGHT: Record<ButtonSize, string> = {
  default: "h-11 md:h-10", // 44 mobile, 40 desktop (D-W0.7)
  auth: "h-[52px]",
  cta: "h-14",
};

const VARIANT: Record<ButtonVariant, { background: string; color: string; border?: string }> = {
  primary: { background: "var(--primary)", color: "var(--on-primary)" },
  secondary: { background: "var(--nested)", color: "var(--text)", border: "1px solid var(--hairline)" },
  tonal: { background: "var(--primary-tint)", color: "var(--on-primary-tint)" },
  ghost: { background: "transparent", color: "var(--text)" },
  // --heart has no dedicated "on-heart" token — verified `--on-primary`
  // (dark text on dark's light primary, white on light's dark primary)
  // happens to also clear AA on both heart tones (6.0:1 dark, 6.46:1 light).
  danger: { background: "var(--heart)", color: "var(--on-primary)" },
};

/**
 * The one button shape (D-W0.7): five variants, four heights, r14, 15/700,
 * pressed = one tone lighter — no ripple, no per-page button styling.
 */
export function Button({
  variant = "primary",
  size = "default",
  fullWidth = false,
  className,
  style,
  disabled,
  children,
  ...rest
}: ButtonProps) {
  const v = VARIANT[variant];
  return (
    <button
      type="button"
      disabled={disabled}
      className={[
        "lifey-button",
        HEIGHT[size],
        fullWidth ? "w-full" : "",
        "inline-flex items-center justify-center gap-2 px-5 type-button rounded-[var(--r-control)]",
        "disabled:opacity-45 disabled:pointer-events-none",
        className,
      ]
        .filter(Boolean)
        .join(" ")}
      style={{ background: v.background, color: v.color, border: v.border, ...style }}
      {...rest}
    >
      {children}
    </button>
  );
}
