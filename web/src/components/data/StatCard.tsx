interface StatCardProps {
  label: string;
  value: string | number;
  unit?: string;
  icon: string;
  color: string;
  ratio?: number; // 0–1 for progress bar
  goalReached?: boolean;
  subtitle?: string;
  onClick?: () => void;
}

export function StatCard({
  label, value, unit, icon, color, ratio, goalReached, subtitle, onClick,
}: StatCardProps) {
  const Tag = onClick ? "button" : "div";

  return (
    <Tag
      onClick={onClick}
      className="flex flex-col gap-3 p-4 rounded-[var(--r-card)] w-full text-left transition-colors"
      style={{
        background: "var(--surface)",
        cursor: onClick ? "pointer" : "default",
      }}
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span
            className="material-symbols-rounded text-xl"
            style={{ color, fontVariationSettings: "'FILL' 1" }}
          >
            {icon}
          </span>
          <span className="text-sm font-semibold" style={{ color: "var(--on-surface-variant)" }}>
            {label}
          </span>
        </div>
        {onClick && (
          <span className="material-symbols-rounded text-lg" style={{ color: "var(--muted)" }}>
            chevron_right
          </span>
        )}
      </div>

      <div>
        <div className="flex items-end gap-1">
          <span className="text-2xl font-extrabold tabular" style={{ color: "var(--on-surface)" }}>
            {typeof value === "number" ? value.toLocaleString() : value}
          </span>
          {unit && (
            <span className="text-sm font-semibold mb-0.5" style={{ color: "var(--on-surface-variant)" }}>
              {unit}
            </span>
          )}
        </div>
        {subtitle && (
          <p className="text-xs mt-0.5" style={{ color: "var(--muted)" }}>{subtitle}</p>
        )}
      </div>

      {ratio !== undefined && (
        <div className="h-1.5 rounded-[var(--r-pill)] overflow-hidden" style={{ background: "var(--surface-highest)" }}>
          <div
            className="h-full rounded-[var(--r-pill)] transition-all duration-[var(--dur-slow)]"
            style={{
              width: `${Math.min(ratio, 1) * 100}%`,
              background: goalReached ? "var(--goal-positive)" : color,
            }}
          />
        </div>
      )}
    </Tag>
  );
}
