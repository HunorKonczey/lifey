import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { buildMetadata } from "@/lib/marketingMetadata";
import { LegalDocument } from "@/components/marketing/legal/LegalDocument";

// Elállási tájékoztató / Withdrawal Notice (docs/landing_page/65 Prompt 8,
// 63 §5, 68 §6) — the standalone page Korm. rendelet 45/2014 requires
// alongside the checkout checkbox. Draft content — not yet reviewed by
// counsel; see this prompt's landed notes in 65-web-landing-page-plan.md.
export const dynamic = "force-static";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "seo.legalWithdrawal" });
  return buildMetadata({ locale, href: "/legal/withdrawal", title: t("metaTitle"), description: t("metaDescription") });
}

export default async function WithdrawalPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations("legal.withdrawal");

  const sections = [1, 2, 3, 4].map((n) => ({
    id: `s${n}`,
    heading: t(`s${n}Heading` as "s1Heading"),
    body: t(`s${n}Body` as "s1Body"),
  }));

  return <LegalDocument title={t("title")} updated={t("updated")} sections={sections} />;
}
