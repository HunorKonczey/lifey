export interface KeyHintProps {
  /** The key as printed on it: "N", "esc", "⌘K". */
  children: string;
  /** `onPrimary` sits on a filled button, `default` on a field or surface. */
  tone?: "default" | "onPrimary";
  className?: string;
}

/**
 * A keycap for a keyboard shortcut ("N" on Add food, "esc" in a search field):
 * a small tinted rounded chip, so it reads as a key and not as part of the
 * label beside it. Never on a phone (narrow) or on any touch-first device (`.keyboard-only`) — there is no keyboard
 * to press it on.
 */
export function KeyHint({ children, tone = "default", className }: KeyHintProps) {
  return (
    <kbd
      aria-hidden
      className={["type-label inline-flex shrink-0 items-center justify-center max-md:hidden keyboard-only", className].filter(Boolean).join(" ")}
      style={{
        minWidth: 22,
        height: 22,
        padding: "0 6px",
        borderRadius: "var(--r-tag)",
        fontFamily: "inherit",
        fontWeight: 700,
        lineHeight: 1,
        background: tone === "onPrimary" ? "color-mix(in srgb, var(--on-primary) 14%, transparent)" : "var(--control)",
        border: `1px solid ${tone === "onPrimary" ? "color-mix(in srgb, var(--on-primary) 35%, transparent)" : "color-mix(in srgb, var(--text) 22%, transparent)"}`,
        color: tone === "onPrimary" ? "var(--on-primary)" : "var(--text-2)",
      }}
    >
      {children}
    </kbd>
  );
}
