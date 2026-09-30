"use client";

import { useTranslations } from "next-intl";
import { Icon } from "@/components/ds";
import { LifeyLogo } from "@/features/auth/components/BrandPanel";

export interface RailStep {
  /** Title ("Rólad"). */
  title: string;
  /** The answer so far ("Nő · 1994. máj. 14."), or the word "Most" on the current step; empty when nothing yet. */
  detail: string;
}

/**
 * The left rail of the onboarding wizard (W6-D, `grid 340 | 1fr`): the logo, the four steps with the answers given
 * so far — done steps tick in the protein tint, the current one is the primary-filled dot — and "Kihagyás, később
 * beállítom" at the bottom. The answers are read live from the form, so the rail updates as the person types.
 */
export function OnboardingRail({ steps, current, onSkip }: { steps: RailStep[]; current: number; onSkip: () => void }) {
  const t = useTranslations("onboarding");
  return (
    <aside
      className="hidden lg:flex flex-col gap-1.5 m-3 px-6 py-7"
      style={{ borderRadius: 22, background: "var(--card)" }}
      aria-label={t("railAria")}
    >
      <div className="pb-7">
        <LifeyLogo size={36} />
      </div>
      <ol className="flex flex-col gap-1.5">
        {steps.map((step, i) => {
          const done = i < current;
          const active = i === current;
          return (
            <li
              key={step.title}
              aria-current={active ? "step" : undefined}
              className="flex items-center gap-3.5 p-3"
              style={{ borderRadius: "var(--r-control)", background: active ? "var(--nested)" : "transparent" }}
            >
              <span
                className="inline-flex items-center justify-center shrink-0"
                style={{
                  width: 32,
                  height: 32,
                  borderRadius: 999,
                  background: done ? "color-mix(in srgb, var(--improvement) 16%, transparent)" : active ? "var(--primary)" : "var(--control)",
                  color: done ? "var(--improvement)" : active ? "var(--on-primary)" : "var(--text-3)",
                  fontWeight: 800,
                  fontSize: 13,
                }}
              >
                {done ? <Icon name="check" size={18} /> : active ? <Icon name="arrow_forward" size={18} /> : i + 1}
              </span>
              <span className="flex flex-col gap-0.5 min-w-0">
                <span style={{ fontSize: 15, lineHeight: 1.3, fontWeight: 700, color: done || active ? "var(--text)" : "var(--text-2)" }}>{step.title}</span>
                {step.detail && (
                  <span className="truncate" style={{ fontSize: 13, lineHeight: 1.3, color: "var(--text-3)" }}>
                    {step.detail}
                  </span>
                )}
              </span>
            </li>
          );
        })}
      </ol>
      <div className="flex-1" />
      <button type="button" onClick={onSkip} className="lifey-button text-left p-3" style={{ fontSize: 14, fontWeight: 600, color: "var(--text-2)", borderRadius: "var(--r-control)" }}>
        {t("skipLong")}
      </button>
    </aside>
  );
}
