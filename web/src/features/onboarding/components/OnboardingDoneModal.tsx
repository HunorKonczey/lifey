"use client";

import { useTranslations } from "next-intl";
import { Button, Icon, Modal } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import type { SuggestGoalsResponse } from "../types";

/**
 * The onboarding finish celebration (W6.8, W6-F): replaces the "You're all set" toast. A check pops once, the title
 * and — when the suggested goals were applied — the daily numbers fade up in turn (`.celebrate-trophy` /
 * `.celebrate-in`, static under reduced motion); the one button goes to the dashboard, where the first-steps card
 * now ticks "goals set". Esc and the scrim do the same as the button.
 */
export function OnboardingDoneModal({ open, applied, plan, onDone }: { open: boolean; applied: boolean; plan: SuggestGoalsResponse | null; onDone: () => void }) {
  const t = useTranslations("onboarding");
  const fmt = useFormat();
  const stagger = (k: number) => ({ "--k": k }) as React.CSSProperties;
  const stats = applied && plan
    ? [
        { label: t("doneKcal"), value: fmt.number(plan.calories), unit: "kcal" },
        { label: t("doneProtein"), value: fmt.number(plan.proteinGrams), unit: "g" },
        { label: t("doneWater"), value: fmt.number(plan.waterLiters, 1), unit: "L" },
      ]
    : [];
  return (
    <Modal open={open} onClose={onDone} width={480} aria-label={t("doneTitle")}>
      <div className="flex flex-col items-center gap-4 p-6 text-center" data-testid="onboarding-done">
        <span
          className="celebrate-trophy flex items-center justify-center"
          style={{ width: 72, height: 72, borderRadius: "var(--r-pill)", background: "color-mix(in srgb, var(--improvement) var(--chip-tint), transparent)" }}
        >
          <Icon name="check" size={40} fill={1} color="var(--improvement)" />
        </span>
        <div className="celebrate-in" style={stagger(0.1)}>
          <h2 className="type-title-l">{t("doneTitle")}</h2>
          <p className="type-body mt-1" style={{ color: "var(--text-2)" }}>{applied ? t("doneBodyApplied") : t("doneBody")}</p>
        </div>
        {stats.length > 0 && (
          <dl className="celebrate-in grid w-full grid-cols-3 gap-3" style={stagger(0.25)}>
            {stats.map((s) => (
              <div key={s.label} className="flex flex-col gap-0.5 p-3" style={{ borderRadius: "var(--r-control)", background: "var(--card)" }}>
                <dt className="type-body-s" style={{ color: "var(--text-2)" }}>{s.label}</dt>
                <dd className="num" style={{ fontSize: 20, fontWeight: 800 }}>
                  {s.value} <span className="type-body-s" style={{ color: "var(--text-2)" }}>{s.unit}</span>
                </dd>
              </div>
            ))}
          </dl>
        )}
        <div className="celebrate-in flex w-full justify-end pt-1" style={stagger(0.45)}>
          <Button onClick={onDone}>{t("doneButton")}</Button>
        </div>
      </div>
    </Modal>
  );
}
