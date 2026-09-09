import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { buildMetadata } from "@/lib/marketingMetadata";
import { LegalDocument } from "@/components/marketing/legal/LegalDocument";

// Impresszum / Imprint (docs/landing_page/65 Prompt 8, 63 §5, 68 §6) —
// required for any commercial site operating in Hungary. Company-identity
// fields (registration number, address, tax number) are explicit
// placeholders, not invented values — see this prompt's landed notes in
// 65-web-landing-page-plan.md for why guessing plausible-looking real IDs
// would be worse than leaving them blank.
export const dynamic = "force-static";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "seo.legalImprint" });
  return buildMetadata({ locale, href: "/legal/imprint", title: t("metaTitle"), description: t("metaDescription") });
}

export default async function ImprintPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations("legal.imprint");

  const sections = [1, 2, 3, 4].map((n) => ({
    id: `s${n}`,
    heading: t(`s${n}Heading` as "s1Heading"),
    body: t(`s${n}Body` as "s1Body"),
  }));

  return <LegalDocument title={t("title")} updated={t("updated")} sections={sections} />;
}
