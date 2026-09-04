import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { buildMetadata } from "@/lib/marketingMetadata";
import { TrainerHero } from "@/components/marketing/for-trainers/TrainerHero";
import { TrainerValueBlock } from "@/components/marketing/for-trainers/TrainerValueBlock";
import { PlanParityMock } from "@/components/marketing/for-trainers/PlanParityMock";
import { SponsoredMock } from "@/components/marketing/for-trainers/SponsoredMock";
import { TrialMock } from "@/components/marketing/for-trainers/TrialMock";
import { DayInLifeStrip } from "@/components/marketing/for-trainers/DayInLifeStrip";
import { ClientsMock } from "@/components/marketing/home/ClientsMock";
import { ProgramMock } from "@/components/marketing/home/ProgramMock";
import { ChatMock } from "@/components/marketing/home/ChatMock";
import { PricingPreview } from "@/components/marketing/home/PricingPreview";
import { FinalCta } from "@/components/marketing/home/FinalCta";

// The for-trainers revenue page (docs/landing_page/65 Prompt 5). No design
// frame exists yet (68 §13.1): six value blocks composed from the home
// page's L10–L12 vocabulary (ValueSection + the three product mockups,
// reused with page-specific copy, plus three new small reproduced-UI mocks
// for facts that aren't a single screen), a "day in the life" strip, and
// the same pricing preview + final CTA the home page uses.
export const dynamic = "force-static";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "seo.forTrainers" });
  return buildMetadata({ locale, href: "/for-trainers", title: t("metaTitle"), description: t("metaDescription") });
}

export default async function ForTrainersPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations("forTrainers");

  const block = (n: 1 | 2 | 3 | 4 | 5 | 6) => ({
    eyebrow: t(`block${n}.eyebrow` as "block1.eyebrow"),
    title: t(`block${n}.title` as "block1.title"),
    body: t(`block${n}.body` as "block1.body"),
    bullets: [
      t(`block${n}.bullet1` as "block1.bullet1"),
      t(`block${n}.bullet2` as "block1.bullet2"),
      t(`block${n}.bullet3` as "block1.bullet3"),
    ],
  });

  return (
    <main>
      <TrainerHero />

      <TrainerValueBlock {...block(1)} visual={<ClientsMock />} imageSide="right" background="bg" />
      <TrainerValueBlock {...block(2)} visual={<ProgramMock />} imageSide="left" background="container" />
      <TrainerValueBlock {...block(3)} visual={<ChatMock />} imageSide="right" background="bg" />
      <TrainerValueBlock {...block(4)} visual={<PlanParityMock />} imageSide="left" background="container" />
      <TrainerValueBlock {...block(5)} visual={<SponsoredMock />} imageSide="right" background="bg" />
      <TrainerValueBlock {...block(6)} visual={<TrialMock />} imageSide="left" background="container" />

      <DayInLifeStrip />
      <PricingPreview page="for-trainers" />
      <FinalCta page="for-trainers" />
    </main>
  );
}
