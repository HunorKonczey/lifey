import { getLocale, getTranslations } from "next-intl/server";
import { getPathname } from "@/i18n/navigation";
import { TrackedCta } from "../TrackedCta";

/**
 * docs/landing_page/65 Prompt 5 — no design frame for this page (68 §13.1).
 * Deliberately text-only, unlike the home hero (Hero.tsx): a bespoke second
 * mockup here would be new illustration invented without a canvas to check
 * it against, and the page already spends its three real product mockups
 * (Clients/Program/Chat, reused below with trainer-page copy) on the value
 * blocks. Same type scale and token usage as the home hero, just centred
 * and without the side panel.
 */
export async function TrainerHero() {
  const t = await getTranslations("forTrainers.hero");
  const locale = await getLocale();

  return (
    <section className="pt-14 md:pt-20 pb-12 md:pb-16" style={{ background: "var(--bg)" }}>
      <div className="max-w-[840px] mx-auto px-4 md:px-8 text-center">
        <div
          className="inline-flex items-center gap-2 h-8 px-3.5 rounded-pill text-[12.5px] font-extrabold tracking-wide"
          style={{ background: "var(--surface-container)", color: "var(--primary)" }}
        >
          <span className="material-symbols-rounded text-base" style={{ fontVariationSettings: "'FILL' 1" }}>
            groups
          </span>
          {t("eyebrow").toUpperCase()}
        </div>
        <h1 className="text-[32px] md:text-[56px] font-extrabold tracking-[-0.02em] leading-[1.08] md:leading-[1.05] mt-4">
          {t("title")}
        </h1>
        <p
          className="hidden md:block text-xl font-medium leading-[1.6] mt-5 max-w-[62ch] mx-auto"
          style={{ color: "var(--on-surface-variant)" }}
        >
          {t("sub")}
        </p>
        <p
          className="md:hidden text-[17px] font-medium leading-[1.55] mt-3.5"
          style={{ color: "var(--on-surface-variant)" }}
        >
          {t("subMobile")}
        </p>

        <div className="flex flex-col md:flex-row gap-3.5 mt-7 md:mt-8 md:justify-center">
          <TrackedCta
            href="/register?next=/admin/pending"
            page="for-trainers"
            slot="hero-primary"
            audience="trainer"
            className="h-14 rounded-pill flex items-center justify-center px-7.5 text-base font-extrabold"
            style={{ background: "var(--primary)", color: "var(--bg)" }}
          >
            {t("ctaPrimary")}
          </TrackedCta>
          <TrackedCta
            href={getPathname({ locale, href: "/pricing" })}
            page="for-trainers"
            slot="hero-secondary"
            audience="trainer"
            className="h-14 rounded-pill flex items-center justify-center px-7.5 text-base font-bold border-[1.5px] border-outline"
          >
            {t("ctaSecondary")}
          </TrackedCta>
        </div>

        <div
          className="flex items-center justify-center gap-2.5 mt-4 md:mt-5 text-sm font-semibold"
          style={{ color: "var(--muted)" }}
        >
          <span
            className="material-symbols-rounded text-lg"
            style={{ color: "var(--tertiary)", fontVariationSettings: "'FILL' 1" }}
          >
            check_circle
          </span>
          {t("reassurance")}
          <span style={{ color: "var(--outline)" }}>·</span>
          <span style={{ color: "var(--secondary)" }}>{t("reassuranceHighlight")}</span>
        </div>
      </div>
    </section>
  );
}
