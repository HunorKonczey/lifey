import type { ReactNode } from "react";

export interface SectionLabelAction {
  label: string;
  href?: string;
  onClick?: () => void;
}

/** A 12/16 caps section header, with an optional trailing "Mind / See all"
 *  link (D-W0.7). */
export function SectionLabel({ children, action, className }: { children: ReactNode; action?: SectionLabelAction; className?: string }) {
  return (
    <div className={["flex items-center justify-between gap-3", className].filter(Boolean).join(" ")}>
      <span className="type-section" style={{ color: "var(--text-3)" }}>{children}</span>
      {action &&
        (action.href ? (
          <a href={action.href} className="type-body-s" style={{ color: "var(--primary)", fontWeight: 700 }}>
            {action.label}
          </a>
        ) : (
          <button
            type="button"
            onClick={action.onClick}
            className="type-body-s"
            style={{ color: "var(--primary)", fontWeight: 700 }}
          >
            {action.label}
          </button>
        ))}
    </div>
  );
}
