import { getTranslations, setRequestLocale } from "next-intl/server";
import { routing } from "@/i18n/routing";

/**
 * The last-resort 404 (docs/landing_page/72 D-F1). Two kinds of request land
 * here rather than on the marketing tree's own `not-found.tsx`:
 *
 * 1. an unknown locale segment (`/de/whatever`) — `(marketing)/[locale]/
 *    layout.tsx` throws `notFound()` from the *layout*, so the boundary
 *    inside that layout cannot render and it bubbles to this one;
 * 2. anything outside the marketing tree entirely (`/random`,
 *    `/dashboard/typo`).
 *
 * Neither case has a locale to honour, so this page is Hungarian — the
 * default locale (65 D-W4), not the browser's. It is deliberately
 * chrome-free: the marketing header/footer are locale-routed components and
 * this page exists precisely for requests where no locale was resolved.
 */
export default async function RootNotFound() {
  setRequestLocale(routing.defaultLocale);
  const t = await getTranslations({ locale: routing.defaultLocale, namespace: "notFound" });

  return (
    <main className="min-h-dvh flex items-center justify-center px-6" style={{ background: "var(--bg)" }}>
      <div className="text-center max-w-[360px]">
        <a href={`/${routing.defaultLocale}`} className="flex items-center justify-center gap-2.5 mb-6">
          <span
            className="w-9 h-9 rounded-md flex items-center justify-center"
            style={{ background: "var(--primary)", color: "var(--bg)" }}
          >
            <span className="material-symbols-rounded text-xl" style={{ fontVariationSettings: "'FILL' 1" }}>
              eco
            </span>
          </span>
          <span className="text-xl font-extrabold">Lifey</span>
        </a>

        <h1 className="text-[28px] font-bold tracking-[-0.02em]">{t("title")}</h1>
        <p className="text-base font-medium mt-3" style={{ color: "var(--on-surface-variant)" }}>
          {t("body")}
        </p>

        <a
          href={`/${routing.defaultLocale}`}
          className="inline-flex h-13 items-center px-7 rounded-pill text-sm font-extrabold mt-7"
          style={{ background: "var(--primary)", color: "var(--bg)" }}
        >
          {t("home")}
        </a>
      </div>
    </main>
  );
}
