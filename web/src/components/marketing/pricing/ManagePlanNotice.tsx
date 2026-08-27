import { getTranslations } from "next-intl/server";
import Link from "next/link";

/**
 * design/Lifey Landing.dc.html L19's bottom info bar. Its copy describes
 * two behaviours; only one is implemented here (see PricingCards.tsx's own
 * comment and 65 Prompt 6 landed notes): the CTA text/destination swap for
 * a signed-in visitor. The per-card "Jelenlegi csomagod" tag needs
 * entitlement data (`66`) that doesn't exist on the frontend yet, so it
 * never renders — a true subset of the stated behaviour, not a false claim.
 */
export async function ManagePlanNotice({ billingHref }: { billingHref: string }) {
  const t = await getTranslations("pricing");

  return (
    <div
      className="mt-7 rounded-lg p-4.5 md:p-5 flex flex-col md:flex-row md:items-center gap-3.5 md:gap-4"
      style={{ background: "var(--surface-container)" }}
    >
      <span className="material-symbols-rounded text-2xl shrink-0" style={{ color: "var(--primary)", fontVariationSettings: "'FILL' 1" }}>
        info
      </span>
      <p className="text-sm flex-1" style={{ color: "var(--on-surface-variant)" }}>
        {t("manageNoticeText")}
      </p>
      <Link
        href={billingHref}
        className="h-11 flex items-center justify-center px-5 rounded-pill text-sm font-bold border-[1.5px] border-outline shrink-0"
      >
        {t("managePlanCta")}
      </Link>
    </div>
  );
}
