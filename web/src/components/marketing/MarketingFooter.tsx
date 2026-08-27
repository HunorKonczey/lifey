import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { FooterLanguageSwitch } from "./FooterLanguageSwitch";
import { StoreBadges } from "./StoreBadges";

/** Server component — design/Lifey Landing.dc.html, L02 (bottom half). */
export async function MarketingFooter() {
  const nav = await getTranslations("nav");
  const footer = await getTranslations("footer");

  return (
    <footer id="site-footer" className="mt-8" style={{ background: "var(--surface)" }}>
      <div className="max-w-[1200px] mx-auto px-4 md:px-8 pt-10 md:pt-12 pb-8">
        <div className="grid grid-cols-1 md:grid-cols-[1.4fr_1fr_1fr_1fr] gap-8">
          <div>
            <div className="flex items-center gap-2.5 mb-3">
              <span
                className="w-8 h-8 rounded-md flex items-center justify-center"
                style={{ background: "var(--primary)", color: "#161611" }}
              >
                <span
                  className="material-symbols-rounded text-xl"
                  style={{ fontVariationSettings: "'FILL' 1" }}
                >
                  eco
                </span>
              </span>
              <span className="text-lg font-extrabold">Lifey</span>
            </div>
            <p className="text-sm max-w-70" style={{ color: "var(--on-surface-variant)" }}>
              {footer("tagline")}
            </p>
            <div className="mt-4">
              <StoreBadges />
            </div>
          </div>

          <FooterColumn heading={footer("productHeading")}>
            <Link href="/for-trainers">{nav("forTrainers")}</Link>
            <Link href="/app">{nav("app")}</Link>
            <Link href="/pricing">{nav("pricing")}</Link>
            <Link href="/download">{footer("download")}</Link>
          </FooterColumn>

          <FooterColumn heading={footer("legalHeading")}>
            <Link href="/legal/terms">{footer("legalTerms")}</Link>
            <Link href="/legal/privacy">{footer("legalPrivacy")}</Link>
            <Link href="/legal/withdrawal">{footer("legalWithdrawal")}</Link>
            <Link href="/legal/imprint">{footer("legalImprint")}</Link>
          </FooterColumn>

          <div>
            <FooterColumn heading={footer("contactHeading")}>
              <Link href="/contact">{footer("contactPage")}</Link>
              <a href={`mailto:${footer("email")}`}>{footer("email")}</a>
              <Link href="/faq">{footer("help")}</Link>
            </FooterColumn>
            <FooterLanguageSwitch />
          </div>
        </div>

        <div
          className="border-t border-outline mt-8 pt-5 text-[12.5px]"
          style={{ color: "var(--muted)" }}
        >
          {footer("copyright", { year: new Date().getFullYear() })}
        </div>
      </div>
    </footer>
  );
}

function FooterColumn({ heading, children }: { heading: string; children: React.ReactNode }) {
  return (
    <div>
      <div
        className="text-xs font-extrabold tracking-wide mb-3 uppercase"
        style={{ color: "var(--muted)" }}
      >
        {heading}
      </div>
      <div className="flex flex-col gap-2.5 text-sm" style={{ color: "var(--on-surface-variant)" }}>
        {children}
      </div>
    </div>
  );
}
