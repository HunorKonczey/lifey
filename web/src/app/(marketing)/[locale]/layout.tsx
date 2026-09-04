import { hasLocale, NextIntlClientProvider } from "next-intl";
import { notFound } from "next/navigation";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { routing } from "@/i18n/routing";
import { MarketingHeader } from "@/components/marketing/MarketingHeader";
import { MarketingFooter } from "@/components/marketing/MarketingFooter";
import { MobileStickyCta } from "@/components/marketing/MobileStickyCta";
import { AttributionCapture } from "@/components/marketing/AttributionCapture";

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export default async function MarketingLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;

  // An unknown locale segment (e.g. /de/...) is a real 404, not a silent
  // redirect (docs/landing_page/65 §3.3) — a soft-404 that returns 200 is an
  // SEO liability.
  if (!hasLocale(routing.locales, locale)) {
    notFound();
  }

  // Enables static rendering for getTranslations/getFormatter calls in
  // children that don't pass an explicit locale. NOT sufficient on its own
  // for a `force-static` page, though — see page.tsx, which repeats this
  // with its own `params`.
  setRequestLocale(locale);

  const stickyCta = await getTranslations("stickyCta");

  return (
    // Locale-only — no `messages`. This is *not* the app's `<Providers>`
    // (D-W6): it exists purely so next-intl's `Link`/`usePathname`/
    // `useLocale` work in the header/footer's client islands (they need
    // *some* IntlContext ancestor even just for routing — confirmed against
    // the compiled source; the original "no client providers" framing in 65
    // D-W1/D-W6 meant the app's heavy provider stack, not this). Every piece
    // of *visible text* stays server-rendered and is passed into the client
    // islands as plain string props, so no messages payload ships to the
    // client and the JS budget (65 §8) is unaffected.
    <NextIntlClientProvider locale={locale}>
      <AttributionCapture />
      <MarketingHeader />
      {children}
      <MarketingFooter />
      <MobileStickyCta cta={stickyCta("cta")} noCard={stickyCta("noCard")} />
    </NextIntlClientProvider>
  );
}
