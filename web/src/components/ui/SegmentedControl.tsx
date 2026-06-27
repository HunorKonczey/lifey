"use client";

interface SegmentOption<T extends string> {
  value: T;
  label: string;
  icon?: string;
}

interface SegmentedControlProps<T extends string> {
  options: SegmentOption<T>[];
  value: T;
  onChange: (value: T) => void;
  size?: "sm" | "md";
}

export function SegmentedControl<T extends string>({
  options, value, onChange, size = "md",
}: SegmentedControlProps<T>) {
  const pad = size === "sm" ? "px-3 py-1 text-xs" : "px-4 py-1.5 text-sm";

  return (
    <div
      className="inline-flex gap-1 p-1 rounded-[var(--r-pill)]"
      style={{ background: "var(--surface-highest)" }}
      role="tablist"
    >
      {options.map((opt) => {
        const active = opt.value === value;
        return (
          <button
            key={opt.value}
            role="tab"
            aria-selected={active}
            onClick={() => onChange(opt.value)}
            className={`flex items-center gap-1.5 rounded-[var(--r-pill)] font-semibold transition-colors ${pad}`}
            style={{
              background: active ? "var(--primary)" : "transparent",
              color: active ? "#1E1F18" : "var(--on-surface-variant)",
            }}
          >
            {opt.icon && (
              <span className="material-symbols-rounded text-base">{opt.icon}</span>
            )}
            {opt.label}
          </button>
        );
      })}
    </div>
  );
}
