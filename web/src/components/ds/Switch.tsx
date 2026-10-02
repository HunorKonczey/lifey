export interface SwitchProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label?: string;
  "aria-label"?: string;
}

/** A pill toggle — track colour carries the on/off state, paired with a
 *  visible label so it's never colour-only (D-W0.7 restyle onto v2 tokens). */
export function Switch({ checked, onChange, label, ...aria }: SwitchProps) {
  return (
    <label className="flex items-center gap-2 cursor-pointer select-none">
      {label && (
        <span className="type-body-s" style={{ color: checked ? "var(--text)" : "var(--text-2)", fontWeight: 600 }}>
          {label}
        </span>
      )}
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        aria-label={aria["aria-label"] ?? label}
        onClick={() => onChange(!checked)}
        className="w-9 h-5 rounded-[var(--r-pill)] relative shrink-0"
        style={{ background: checked ? "var(--primary)" : "var(--control)", transition: `background var(--dur-hover) var(--ease-standard)` }}
      >
        <span
          className="absolute top-[3px] w-3.5 h-3.5 rounded-full"
          style={{
            left: checked ? "calc(100% - 17px)" : "3px",
            background: checked ? "var(--on-primary)" : "var(--text-2)",
            transition: `left var(--dur-hover) var(--ease-standard)`,
          }}
        />
      </button>
    </label>
  );
}
