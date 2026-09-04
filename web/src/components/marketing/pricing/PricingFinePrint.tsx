import { getTranslations } from "next-intl/server";
import { MOBILE_PRO, formatHuf } from "@/lib/pricing";

/**
 * design/Lifey Landing.dc.html L19's fine-print row: legal/pricing note on
 * one side, the "Mobil Pro" individual-subscriber card (63 D-M6) on the
 * other — this is where §5.3's "Mobile Pro block" actually lives on
 * desktop, not as its own full-width section like the spec text implies.
 * On mobile (L20) the Mobile Pro card comes first, the legal text after —
 * `order` classes flip the two without duplicating either.
 */
export async function PricingFinePrint() {
  const t = await getTranslations("pricing");

  return (
    <div className="grid md:grid-cols-[1.2fr_1fr] gap-6 mt-8 items-start">
      <div className="order-2 md:order-1">
        <p className="hidden md:block text-[13px] leading-[1.75]" style={{ color: "var(--muted)" }}>
          {t("finePrint")}
        </p>
        <p className="md:hidden text-xs leading-[1.7]" style={{ color: "var(--muted)" }}>
          {t("finePrintMobile")}
        </p>
      </div>

      <div className="order-1 md:order-2 rounded-lg p-5.5" style={{ background: "var(--surface-container)" }}>
        <div className="flex items-center gap-2">
          <span className="material-symbols-rounded text-xl" style={{ color: "var(--secondary)", fontVariationSettings: "'FILL' 1" }}>
            smartphone
          </span>
          <div className="text-[13px] font-extrabold tracking-wide" style={{ color: "var(--secondary)" }}>
            {t("mobileProLabel").toUpperCase()}
          </div>
        </div>

        <div className="hidden md:block">
          <div className="text-lg font-bold mt-2.5">{t("mobileProTitle")}</div>
          <p className="text-sm leading-[1.55] mt-1.5" style={{ color: "var(--on-surface-variant)" }}>
            {t("mobileProBody")}
          </p>
          <div className="text-lg font-extrabold tabular-nums mt-3">
            {t("mobileProPrice", {
              monthly: formatHuf(MOBILE_PRO.monthlyHuf),
              yearly: formatHuf(MOBILE_PRO.yearlyHuf),
            })}
          </div>
        </div>

        <div className="md:hidden">
          <div className="text-base font-bold mt-1.5">
            {t("mobileProTitleMobile", { monthly: formatHuf(MOBILE_PRO.monthlyHuf) })}
          </div>
          <div className="text-[13px] tabular-nums mt-0.5" style={{ color: "var(--muted)" }}>
            {t("mobileProSubMobile", { yearly: formatHuf(MOBILE_PRO.yearlyHuf) })}
          </div>
        </div>
      </div>
    </div>
  );
}
