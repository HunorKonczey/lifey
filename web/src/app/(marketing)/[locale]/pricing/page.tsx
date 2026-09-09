import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { PLANS, buildPricingOffers } from "@/lib/pricing";
import { SITE_URL } from "@/lib/site";
import { buildMetadata } from "@/lib/marketingMetadata";
import { getPathname } from "@/i18n/navigation";
import { PricingCards } from "@/components/marketing/pricing/PricingCards";
import { PricingFinePrint } from "@/components/marketing/pricing/PricingFinePrint";
import { ManagePlanNotice } from "@/components/marketing/pricing/ManagePlanNotice";
import { BillingFaq } from "@/components/marketing/pricing/BillingFaq";

// The full pricing page (docs/landing_page/65 Prompt 6), frames L19–L20.
// DV-5 (68 §12.2 — the Studio card's phantom "multiple trainers" bullet) is
// fixed at the source, in `lib/pricing.ts`'s shared PLANS constant, which
// this page and the home page's preview (§4.10) both render from — the
// same fix already landed in Prompt 4 covers this page automatically.
export const dynamic = "force-static";

const BILLING_HREF = "/admin/billing";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "seo.pricing" });
  return buildMetadata({ locale, href: "/pricing", title: t("metaTitle"), description: t("metaDescription") });
}

export default async function PricingPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations("pricing");

  const bulletsFor = (plan: (typeof PLANS)[number]) => [
    t("bulletAllFeatures"),
    plan.seats ? t("bulletSponsoredFor", { seats: plan.seats }) : t("bulletSponsoredAll"),
    // DV-5: identical across all three tiers, deliberately — see lib/pricing.ts.
    t("bulletScheduling"),
  ];

  const names: Record<string, string> = {
    starter: t("starterName"),
    pro: t("proName"),
    studio: t("studioName"),
  };

  const plans = PLANS.map((plan) => ({
    id: plan.id,
    name: names[plan.id],
    seats: plan.seats,
    unlimitedLabel: t("unlimited"),
    activeClientsLabel: t("activeClients"),
    yearlyPriceHuf: plan.yearlyPriceHuf,
    monthlyPriceHuf: plan.monthlyPriceHuf,
    bullets: bulletsFor(plan),
    recommended: plan.recommended,
  }));

  const pageUrl = `${SITE_URL}${getPathname({ locale, href: "/pricing" })}`;
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "Product",
    name: "Lifey — edzői előfizetés",
    offers: buildPricingOffers(pageUrl),
  };

  return (
    <main>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />

      <section className="pt-14 md:pt-20 pb-16 md:pb-24" style={{ background: "var(--bg)" }}>
        <div className="max-w-[1200px] mx-auto px-4 md:px-8">
          <div className="text-center max-w-[720px] mx-auto">
            <h1 className="text-[32px] md:text-[44px] font-bold tracking-[-0.02em]">{t("title")}</h1>
            <p className="text-lg md:text-xl mt-3.5" style={{ color: "var(--on-surface-variant)" }}>
              {t("subtitle")}
            </p>
          </div>

          <div className="mt-9">
            <PricingCards
              plans={plans}
              billingHref={BILLING_HREF}
              labels={{
                toggleMonthly: t("toggleMonthly"),
                toggleYearly: t("toggleYearly"),
                toggleYearlyBadge: t("toggleYearlyBadge"),
                toggleYearlyBadgeMobile: t("toggleYearlyBadgeMobile"),
                perYear: t("perYear"),
                perMonth: t("perMonth"),
                perMonthSuffix: t("perMonth"),
                billedMonthlyPrefix: t("billedMonthlyPrefix"),
                trialBadge: t("trialBadge"),
                recommendedBadge: t("recommendedBadge"),
                planCta: t("planCta"),
                managePlanCta: t("managePlanCta"),
              }}
            />
          </div>

          <PricingFinePrint />
          <ManagePlanNotice billingHref={BILLING_HREF} />
        </div>
      </section>

      <BillingFaq />
    </main>
  );
}
