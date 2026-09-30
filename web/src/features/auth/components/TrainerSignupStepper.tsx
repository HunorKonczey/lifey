import { useTranslations } from "next-intl";
import { Icon } from "@/components/ds";

/**
 * The trainer registration's header (W6-B): the clay **"Edzői fiók"** badge and the three-step line
 * "1. Fiók · 2. Jelentkezés · 3. 14 nap ingyen" with the current step (the account) in bold. Clay is the trainer role's
 * colour everywhere (D-W0.4) — never the primary green.
 */
export function TrainerSignupStepper({ current = 1 }: { current?: 1 | 2 | 3 }) {
  const t = useTranslations("auth");
  const steps = [t("trainerStepAccount"), t("trainerStepRequest"), t("trainerStepTrial")];
  return (
    <div className="flex items-center gap-2.5 flex-wrap" data-testid="trainer-stepper">
      <span
        className="inline-flex items-center gap-1.5 px-2.5 type-body-s"
        style={{ height: 28, borderRadius: 999, background: "var(--role-tint)", color: "var(--role)", fontWeight: 700 }}
      >
        <Icon name="sports" size={16} />
        {t("trainerBadge")}
      </span>
      <ol className="flex items-center gap-1.5 type-body-s" style={{ color: "var(--text-2)" }} aria-label={t("trainerStepsAria")}>
        {steps.map((label, i) => (
          <li key={label} aria-current={i + 1 === current ? "step" : undefined} style={{ fontWeight: i + 1 === current ? 700 : 600, color: i + 1 === current ? "var(--text)" : undefined }}>
            {i + 1}. {label}
            {i < steps.length - 1 && <span aria-hidden> ·</span>}
          </li>
        ))}
      </ol>
    </div>
  );
}
