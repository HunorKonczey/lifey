import type { ReactNode } from "react";
import { Card } from "@/components/ds";

/**
 * One block of the one-page settings (W6-G): a title row with an optional action on the right, then the body. The
 * `id` is what the anchor list scrolls to and observes; `scroll-mt` keeps the title clear of the sticky top bar.
 */
export function SettingsSection({ id, title, action, children }: { id: string; title: string; action?: ReactNode; children: ReactNode }) {
  return (
    <section id={id} data-settings-section aria-labelledby={`${id}-title`} className="scroll-mt-24">
      <Card variant="card" className="flex flex-col gap-5 !p-5 md:!p-6">
        <div className="flex items-center justify-between gap-3">
          <h2 id={`${id}-title`} style={{ fontSize: 20, lineHeight: 1.2, fontWeight: 800 }}>{title}</h2>
          {action}
        </div>
        {children}
      </Card>
    </section>
  );
}

/** A label (+ hint) on the left, its control on the right; stacks on a narrow card. */
export function SettingsRow({ label, hint, children }: { label: string; hint?: string; children: ReactNode }) {
  return (
    <div className="flex flex-col gap-2.5 sm:flex-row sm:items-center sm:justify-between sm:gap-6">
      <div className="min-w-0">
        <div className="type-body" style={{ fontWeight: 700 }}>{label}</div>
        {hint && <div className="type-body-s" style={{ color: "var(--text-2)" }}>{hint}</div>}
      </div>
      <div className="shrink-0">{children}</div>
    </div>
  );
}
