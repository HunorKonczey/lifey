import { hasLocale, NextIntlClientProvider } from "next-intl";
import { notFound } from "next/navigation";
import { setRequestLocale } from "next-intl/server";
import { routing } from "@/i18n/routing";
import { AttributionCapture } from "@/components/marketing/AttributionCapture";

/**
 * A second, sibling route group to `(marketing)` — same `[locale]`
 * segment, same proxy matcher (`src/proxy.ts` matches on URL shape, not on
 * which Next.js route group handles it), but deliberately without
 * `MarketingHeader`/`MarketingFooter`/`MobileStickyCta`.
 *
 * Exists for the download page (69 §6.1: "no header nav, no footer nav" —
 * it's opened on a phone, in a hurry, next to a trainer; chrome is
 * friction). Next.js layouts nest — a child page cannot remove ancestor
 * UI a shared `(marketing)/[locale]/layout.tsx` already rendered — so the
 * only way to give one page no chrome without touching every other
 * marketing page is a separate layout tree. This duplicates the parent
 * layout's locale-validation block (not worth a shared abstraction for a
 * two-consumer, ~10-line block) but drops the header/footer/sticky-CTA.
 */
export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export default async function BareMarketingLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;

  if (!hasLocale(routing.locales, locale)) {
    notFound();
  }

  setRequestLocale(locale);

  return (
    <NextIntlClientProvider locale={locale}>
      <AttributionCapture />
      {children}
    </NextIntlClientProvider>
  );
}
