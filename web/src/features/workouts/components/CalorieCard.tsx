import { useTranslations } from "next-intl";

interface CalorieCardProps {
  activeCalories: number | null;
  machineCalories: number | null;
  machineEdited: boolean;
  accent: string;
}

/**
 * M39's calorie card — **one card, two sides, a line between them**
 * (docs/cardio/60 §8 C7w.2), the web port of the mobile `_CalorieCard`.
 *
 * The left side is the app's own estimate, in the calorie accent at full
 * contrast, and it's the one that counts towards the day. The right side is
 * what the machine displayed, in a secondary tone: informative, never added
 * (docs/cardio/51 Q4) — the footnote says why. Two separate cards read as
 * two comparable numbers and invite the suspicion that something sums them;
 * one card with a dividing line does not.
 *
 * **Always rendered for a MACHINE session**, matching mobile exactly — even
 * when both sides are null, both show "—" rather than the card
 * disappearing. Unlike most of this page's other cards, "no data yet" is
 * still worth explaining (the footnote), not just hiding.
 */
export function CalorieCard({ activeCalories, machineCalories, machineEdited, accent }: CalorieCardProps) {
  const t = useTranslations("workouts");

  return (
    <div className="rounded-[var(--r-card)] p-4" style={{ background: "var(--surface)" }}>
      <div className="flex items-start">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-1.5">
            <span className="material-symbols-rounded text-sm" style={{ color: accent }}>
              local_fire_department
            </span>
            <span className="text-[10px] font-extrabold tracking-wide uppercase" style={{ color: accent }}>
              {t("cardioActiveCaloriesLabel")}
            </span>
          </div>
          <p className="text-[26px] font-extrabold tabular leading-tight mt-1" style={{ color: accent }}>
            {activeCalories != null ? Math.round(activeCalories) : "—"}
          </p>
          <p className="text-[10.5px]" style={{ color: "var(--on-surface-variant)" }}>
            {t("cardioActiveCaloriesHint")}
          </p>
        </div>

        <div className="w-px self-stretch mx-5" style={{ background: "var(--outline)" }} />

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-1.5">
            <span className="material-symbols-rounded text-sm" style={{ color: "var(--on-surface-variant)" }}>
              monitor
            </span>
            <span
              className="text-[10px] font-extrabold tracking-wide uppercase"
              style={{ color: "var(--on-surface-variant)" }}
            >
              {t("cardioMachineCaloriesLabel")}
            </span>
            {machineEdited && (
              <span className="text-[9px] font-bold" style={{ color: "var(--on-surface-variant)" }}>
                {t("cardioManuallyEditedBadge")}
              </span>
            )}
          </div>
          <p
            className="text-[26px] font-extrabold tabular leading-tight mt-1"
            style={{ color: "var(--on-surface-variant)" }}
          >
            {machineCalories != null ? Math.round(machineCalories) : "—"}
          </p>
          <p className="text-[10.5px]" style={{ color: "var(--on-surface-variant)" }}>
            {t("cardioMachineCaloriesHint")}
          </p>
        </div>
      </div>

      <div className="flex items-start gap-2 mt-3.5">
        <span className="material-symbols-rounded text-sm" style={{ color: "var(--on-surface-variant)" }}>
          info
        </span>
        <p className="text-[11px] leading-snug" style={{ color: "var(--on-surface-variant)" }}>
          {t("cardioMachineCaloriesFootnote")}
        </p>
      </div>
    </div>
  );
}
