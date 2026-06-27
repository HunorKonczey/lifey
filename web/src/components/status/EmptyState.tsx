interface EmptyStateProps {
  icon?: string;
  title?: string;
  body?: string;
  action?: React.ReactNode;
}

export function EmptyState({
  icon = "inbox",
  title = "Nothing here yet",
  body = "Add your first entry to get started.",
  action,
}: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center gap-4 py-16 text-center">
      <div
        className="w-16 h-16 rounded-full flex items-center justify-center"
        style={{ background: "var(--surface-highest)" }}
      >
        <span
          className="material-symbols-rounded text-3xl"
          style={{ color: "var(--on-surface-variant)", fontVariationSettings: "'FILL' 1" }}
        >
          {icon}
        </span>
      </div>
      <div>
        <p className="font-bold text-base mb-1">{title}</p>
        <p className="text-sm max-w-xs" style={{ color: "var(--on-surface-variant)" }}>
          {body}
        </p>
      </div>
      {action}
    </div>
  );
}
