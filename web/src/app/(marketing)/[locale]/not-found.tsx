import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";

/**
 * The marketing tree's 404 (docs/landing_page/72 D-F1, `68` §13 item 4 —
 * specified, never drawn). Rendered inside `(marketing)/[locale]/layout.tsx`,
 * so it keeps the header, the footer and the theme: a visitor who mistyped a
 * URL lands somewhere that still looks like the site and has a way out.
 *
 * Reached from `[...rest]/page.tsx` (an unmatched path under a *known*
 * locale). An unknown locale segment is a different case — the layout above
 * throws `notFound()` before this boundary exists, so that one falls to the
 * root `app/not-found.tsx` in Hungarian.
 *
 * The `(marketing-bare)` group deliberately has no not-found of its own:
 * `/hu/letoltes/anything` is matched by the catch-all in *this* group, so a
 * bare 404 is unreachable and would only be dead code (72 §6 edge case 1 is
 * corrected accordingly).
 */
export default async function MarketingNotFound() {
  const t = await getTranslations("notFound");

  return (
    <main className="py-20 md:py-28" style={{ background: "var(--bg)" }}>
      <div className="max-w-[560px] mx-auto px-4 md:px-8 text-center">
        <div
          className="text-[13px] font-extrabold tracking-[0.12em]"
          style={{ color: "var(--secondary)" }}
        >
          {t("eyebrow")}
        </div>
        <h1 className="text-[32px] md:text-[44px] font-bold tracking-[-0.02em] mt-3">{t("title")}</h1>
        <p className="text-base md:text-lg mt-3" style={{ color: "var(--on-surface-variant)" }}>
          {t("body")}
        </p>

        <div className="flex flex-wrap items-center justify-center gap-3 mt-8">
          <Link
            href="/"
            className="inline-flex h-13 items-center px-7 rounded-pill text-sm font-extrabold"
            style={{ background: "var(--primary)", color: "var(--bg)" }}
          >
            {t("home")}
          </Link>
          <Link
            href="/pricing"
            className="inline-flex h-13 items-center px-7 rounded-pill text-sm font-extrabold border border-outline"
          >
            {t("pricing")}
          </Link>
        </div>
      </div>
    </main>
  );
}
