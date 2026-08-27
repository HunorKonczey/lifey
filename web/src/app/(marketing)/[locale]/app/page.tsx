import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { buildMetadata } from "@/lib/marketingMetadata";
import { MOBILE_PRO, formatHuf } from "@/lib/pricing";
import { AppHero } from "@/components/marketing/app/AppHero";
import { AppFeatureGrid } from "@/components/marketing/app/AppFeatureGrid";
import { AppScreenshotRow } from "@/components/marketing/app/AppScreenshotRow";
import { StoreBadges } from "@/components/marketing/StoreBadges";

// The app page (docs/landing_page/65 Prompt 7) — the individual-user
// "consumer story" (65 §4): nutrition, workouts, cardio, watch, offline.
// No design frame (68 §13.2); see AppHero.tsx's own comment for the one
// frame deviation (one phone, not three).
export const dynamic = "force-static";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "seo.app" });
  return buildMetadata({ locale, href: "/app", title: t("metaTitle"), description: t("metaDescription") });
}

export default async function AppPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations("app.finalCta");

  // SoftwareApplication (65 §5.2) — the free tier and Mobile Pro (63 D-M6),
  // the same MOBILE_PRO constant PricingFinePrint.tsx renders, so this and
  // the visible price can't drift apart the way §10 edge case 4 warns about.
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "Lifey",
    applicationCategory: "HealthApplication",
    operatingSystem: "iOS, Android",
    offers: [
      { "@type": "Offer", name: "Free", price: "0", priceCurrency: "HUF" },
      {
        "@type": "Offer",
        name: "Pro",
        price: String(MOBILE_PRO.monthlyHuf),
        priceCurrency: "HUF",
        description: formatHuf(MOBILE_PRO.monthlyHuf) + " / hó",
      },
    ],
  };

  return (
    <main>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <AppHero />
      <AppFeatureGrid />
      <AppScreenshotRow />

      <section className="py-16 md:py-20 text-center" style={{ background: "var(--surface-container)" }}>
        <div className="max-w-[600px] mx-auto px-4">
          <h2 className="text-[26px] md:text-[36px] font-bold tracking-[-0.02em]">{t("title")}</h2>
          <p className="text-base md:text-lg mt-3" style={{ color: "var(--on-surface-variant)" }}>
            {t("body")}
          </p>
          <div className="mt-7 flex justify-center">
            <StoreBadges size="lg" page="app" />
          </div>
        </div>
      </section>
    </main>
  );
}
