import { notFound } from "next/navigation";
import { setRequestLocale } from "next-intl/server";
import { hasLocale } from "next-intl";
import { routing } from "@/i18n/routing";

/**
 * Catch-all under a known locale, purely so an unmatched marketing URL gets
 * the branded, localized 404 (`not-found.tsx` next to this file) instead of
 * Next.js's built-in English error page (docs/landing_page/72 D-F1).
 *
 * Without this file, `/hu/nincs-ilyen-oldal` matches no route at all, and an
 * unmatched URL always renders the *root* `app/not-found.tsx` — nested
 * not-found boundaries only apply to a `notFound()` thrown inside their own
 * subtree. Calling it here is what puts the request inside the marketing
 * subtree first, so the shell (header/footer/theme) renders around it.
 *
 * Deliberately not statically generated: there is no finite set of wrong
 * URLs to enumerate, and a 404 answering from the edge is not worth a
 * `generateStaticParams` that could never be complete.
 */
export default async function MarketingCatchAll({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;

  // The layout above has already rejected an unknown locale; this repeats the
  // check only so `setRequestLocale` is never called with a bogus value.
  if (hasLocale(routing.locales, locale)) {
    setRequestLocale(locale);
  }

  notFound();
}
