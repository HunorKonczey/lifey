import { getTranslations } from "next-intl/server";
import { renderOgImage, OG_IMAGE_SIZE, OG_IMAGE_CONTENT_TYPE } from "@/lib/ogImage";
import { routing } from "@/i18n/routing";

export const alt = "Lifey";
export const size = OG_IMAGE_SIZE;
export const contentType = OG_IMAGE_CONTENT_TYPE;

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export default async function Image({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  const seo = await getTranslations({ locale, namespace: "seo.faq" });
  const faq = await getTranslations({ locale, namespace: "faq" });
  return renderOgImage({ eyebrow: seo("ogEyebrow"), title: faq("title") });
}
