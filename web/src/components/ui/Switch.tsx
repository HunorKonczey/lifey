"use client";

interface SwitchProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label?: string;
  "aria-label"?: string;
}

/** Small pill toggle (e.g. "Show cancelled") — track color carries the on/off state,
 *  paired with a visible label so it's never color-only. */
export function Switch({ checked, onChange, label, ...aria }: SwitchProps) {
  return (
    <label className="flex items-center gap-2 cursor-pointer select-none">
      {label && (
        <span className="text-xs font-semibold" style={{ color: checked ? "var(--on-surface)" : "var(--on-surface-variant)" }}>
          {label}
        </span>
      )}
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        aria-label={aria["aria-label"] ?? label}
        onClick={() => onChange(!checked)}
        className="w-9 h-5 rounded-[var(--r-pill)] relative shrink-0 transition-colors"
        style={{ background: checked ? "var(--tertiary)" : "var(--outline)" }}
      >
        <span
          className="absolute top-[3px] w-3.5 h-3.5 rounded-full transition-all"
          style={{
            left: checked ? "calc(100% - 17px)" : "3px",
            background: checked ? "#161611" : "var(--on-surface-variant)",
          }}
        />
      </button>
    </label>
  );
}
