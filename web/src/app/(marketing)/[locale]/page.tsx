import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { buildMetadata } from "@/lib/marketingMetadata";
import { SITE_URL } from "@/lib/site";
import { Hero } from "@/components/marketing/home/Hero";
import { Fork } from "@/components/marketing/home/Fork";
import { ProofStrip } from "@/components/marketing/home/ProofStrip";
import { ClientsSection } from "@/components/marketing/home/ClientsSection";
import { ProgramSection } from "@/components/marketing/home/ProgramSection";
import { ChatSection } from "@/components/marketing/home/ChatSection";
import { SponsoredBand } from "@/components/marketing/home/SponsoredBand";
import { HowItWorks } from "@/components/marketing/home/HowItWorks";
import { FeatureGrid } from "@/components/marketing/home/FeatureGrid";
import { PricingPreview } from "@/components/marketing/home/PricingPreview";
import { FaqPreview } from "@/components/marketing/home/FaqPreview";
import { FinalCta } from "@/components/marketing/home/FinalCta";

// The real home page (docs/landing_page/65 Prompt 4), built section by
// section from design/Lifey Landing.dc.html frames L04–L18 and L21 — order
// matches 68 §4 exactly (hero, fork, proof, three value blocks, sponsored
// band, how-it-works, feature grid, pricing preview, FAQ preview, final CTA).
export const dynamic = "force-static";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "seo.home" });
  return buildMetadata({ locale, href: "/", title: t("metaTitle"), description: t("metaDescription") });
}

export default async function MarketingHomePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  // Repeats the layout's setRequestLocale with this page's own `params`
  // (next-intl's documented pattern, not redundant): React's per-request
  // `cache()` doesn't reliably carry a value set by an ancestor layout down
  // into a page rendered under `force-static` — without this, every page
  // under `[locale]` silently rendered with the default-locale messages
  // regardless of the URL. Every future page here needs the same two lines.
  const { locale } = await params;
  setRequestLocale(locale);

  // Organization + WebSite (65 §5.2) — kept minimal and honest: no `logo`
  // (no real brand-mark asset exists in the repo, so pointing at one would
  // be wrong) and no `sameAs`/search action (no social presence or site
  // search exists yet either).
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      { "@type": "Organization", name: "Lifey", url: SITE_URL },
      { "@type": "WebSite", name: "Lifey", url: SITE_URL },
    ],
  };

  return (
    <main>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <Hero />
      <Fork />
      <ProofStrip />
      <ClientsSection />
      <ProgramSection />
      <ChatSection />
      <SponsoredBand />
      <HowItWorks />
      <FeatureGrid />
      <PricingPreview />
      <FaqPreview />
      <FinalCta />
    </main>
  );
}
