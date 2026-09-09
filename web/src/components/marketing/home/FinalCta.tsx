import { getTranslations } from "next-intl/server";
import { TrackedCta } from "../TrackedCta";

/**
 * design/Lifey Landing.dc.html L21 (bottom half) — headline, one CTA, nothing else.
 * Also reused as-is on the for-trainers page (65 Prompt 5); the copy ("Kezdd
 * el a táblázat nélkül") is generic enough to work on both. `page` keeps
 * `?src=`/`cta_click` attribution honest about which page the click came
 * from (65 Prompt 10 — previously a single hand-typed `src` string, now
 * `page`/`slot` like every other TrackedCta call site) — and, on for-trainers
 * specifically, also routes the click into the trainer-request flow (66 D-T1)
 * rather than a plain signup; the home page's own instance stays a plain
 * `/register`, since a home-page visitor hasn't signaled trainer intent.
 */
export async function FinalCta({ page = "home" }: { page?: string }) {
  const t = await getTranslations("home.finalCta");
  const href = page === "for-trainers" ? "/register?next=/admin/pending" : "/register";

  return (
    <section className="py-16 md:py-24" style={{ background: "var(--surface-container)" }}>
      <div className="max-w-[1200px] mx-auto px-4 md:px-8 text-center">
        <h2 className="text-[36px] md:text-[64px] font-extrabold tracking-[-0.02em] leading-[1.06] md:leading-[1.04] max-w-[18ch] mx-auto">
          {t("title")}
        </h2>
        <TrackedCta
          href={href}
          page={page}
          slot="final-cta"
          audience="trainer"
          className="inline-flex h-14 items-center px-8.5 rounded-pill text-base font-extrabold mt-8"
          style={{ background: "var(--primary)", color: "var(--bg)" }}
        >
          {t("cta")}
        </TrackedCta>
        <p className="text-sm font-semibold mt-4.5" style={{ color: "var(--muted)" }}>
          {t("reassurance")}
          <span style={{ color: "var(--outline)" }}> · </span>
          <span style={{ color: "var(--secondary)" }}>{t("reassuranceHighlight")}</span>
        </p>
      </div>
    </section>
  );
}
