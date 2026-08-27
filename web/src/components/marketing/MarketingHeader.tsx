import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { MarketingHeaderShell } from "./MarketingHeaderShell";
import { MarketingNav } from "./MarketingNav";
import { HeaderAuthActions } from "./HeaderAuthActions";
import { MobileMenu } from "./MobileMenu";

/**
 * Server component — logo and nav labels are rendered straight into the HTML
 * (design/Lifey Landing.dc.html, L02). Only the pieces that genuinely need
 * the browser (active-path highlighting, auth state, the mobile drawer) are
 * client islands underneath.
 */
export async function MarketingHeader() {
  const nav = await getTranslations("nav");
  const header = await getTranslations("header");

  const navLabels = {
    forTrainers: nav("forTrainers"),
    app: nav("app"),
    pricing: nav("pricing"),
    faq: nav("faq"),
  };
  const authLabels = {
    login: header("login"),
    trialCta: header("trialCta"),
    backToApp: header("backToApp"),
  };
  const menuLabels = {
    openMenu: header("openMenu"),
    closeMenu: header("closeMenu"),
  };

  return (
    <MarketingHeaderShell>
      <div className="max-w-[1200px] mx-auto px-4 md:px-8 h-16 md:h-20 flex items-center gap-8">
        <Link href="/" className="flex items-center gap-2.5 shrink-0">
          <span
            className="w-[34px] h-[34px] rounded-md flex items-center justify-center"
            style={{ background: "var(--primary)", color: "#161611" }}
          >
            <span
              className="material-symbols-rounded text-[21px]"
              style={{ fontVariationSettings: "'FILL' 1" }}
            >
              eco
            </span>
          </span>
          <span className="text-[19px] font-extrabold tracking-tight">Lifey</span>
        </Link>

        <MarketingNav labels={navLabels} variant="desktop" />

        <div className="ml-auto hidden md:flex">
          <HeaderAuthActions labels={authLabels} variant="desktop" />
        </div>
        <MobileMenu navLabels={navLabels} authLabels={authLabels} menuLabels={menuLabels} />
      </div>
    </MarketingHeaderShell>
  );
}
