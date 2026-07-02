"use client";

interface OptionCardProps {
  icon: string;
  label: string;
  description?: string;
  active: boolean;
  onClick: () => void;
}

/** Large selection card used for gender/activity/goal pickers in the onboarding wizard. */
export function OptionCard({ icon, label, description, active, onClick }: OptionCardProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      className="flex flex-col items-start gap-1.5 p-4 rounded-[var(--r-card)] text-left transition-colors w-full"
      style={{
        background: active ? "color-mix(in srgb, var(--primary) 16%, var(--surface))" : "var(--surface-container)",
        border: `1px solid ${active ? "var(--primary)" : "var(--outline)"}`,
      }}
    >
      <span
        className="material-symbols-rounded text-2xl"
        style={{ color: active ? "var(--primary)" : "var(--on-surface-variant)" }}
      >
        {icon}
      </span>
      <span className="text-sm font-semibold">{label}</span>
      {description && (
        <span className="text-xs" style={{ color: "var(--on-surface-variant)" }}>
          {description}
        </span>
      )}
    </button>
  );
}
