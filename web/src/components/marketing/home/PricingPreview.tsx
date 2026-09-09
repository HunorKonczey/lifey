import { getTranslations, getLocale } from "next-intl/server";
import { Link, getPathname } from "@/i18n/navigation";
import { PLANS, formatHuf } from "@/lib/pricing";
import { TrackedCta } from "../TrackedCta";

/**
 * design/Lifey Landing.dc.html §4.10 has no frame of its own by design — it
 * reuses the pricing page's card, fine print and toggle dropped (68 §4.10).
 * Built from the shared `PLANS` constant so Prompt 6's full pricing page
 * (L19/L20) never has a second, hand-typed copy of these numbers.
 *
 * Also reused as-is on the for-trainers page (65 Prompt 5) — `page` (was
 * `srcPrefix` before 65 Prompt 10) keeps `?src=`/`cta_click` attribution
 * honest about which page a click came from instead of every plan CTA
 * site-wide reading "home-pricing-*". Only the three plan CTAs are tracked
 * (`TrackedCta`, `cta_click`) — the "see all plans" link below them is a
 * secondary nav link, not a conversion CTA, so it keeps its `?src=`
 * attribution but doesn't fire an event.
 */
export async function PricingPreview({ page = "home" }: { page?: string }) {
  const t = await getTranslations("home.pricingPreview");
  const locale = await getLocale();
  const pricingHref = getPathname({ locale, href: "/pricing" });

  const names: Record<string, string> = {
    starter: t("starterName"),
    pro: t("proName"),
    studio: t("studioName"),
  };

  return (
    <section className="py-16 md:py-24" style={{ background: "var(--surface-container)" }}>
      <div className="max-w-[1200px] mx-auto px-4 md:px-8">
        <div className="text-xs font-extrabold tracking-wide" style={{ color: "var(--primary)" }}>
          {t("eyebrow").toUpperCase()}
        </div>
        <h2 className="text-[28px] md:text-[44px] font-bold tracking-[-0.02em] mt-3.5 max-w-[18ch]">
          {t("title")}
        </h2>

        <div className="grid md:grid-cols-3 gap-5 mt-9">
          {PLANS.map((plan) => {
            const bullet2 = plan.seats
              ? t("bulletSponsoredFor", { seats: plan.seats })
              : t("bulletSponsoredAll");
            return (
              <div
                key={plan.id}
                className="rounded-lg p-6 md:p-7 relative"
                style={{
                  background: "var(--bg)",
                  border: plan.recommended ? "2px solid var(--primary)" : "1px solid var(--outline)",
                  boxShadow: plan.recommended ? "0 8px 32px rgba(0,0,0,.18)" : undefined,
                }}
              >
                {plan.recommended && (
                  <div
                    className="absolute -top-3 left-6 h-6 flex items-center px-2.5 rounded-pill text-[10.5px] font-extrabold tracking-wide"
                    style={{ background: "var(--primary)", color: "var(--bg)" }}
                  >
                    {t("recommended").toUpperCase()}
                  </div>
                )}
                <div className="text-xs font-extrabold tracking-wide" style={{ color: "var(--muted)" }}>
                  {names[plan.id].toUpperCase()}
                </div>
                <div className="text-[40px] font-extrabold tracking-[-0.02em] tabular-nums mt-2">
                  {plan.seats ?? t("unlimited")}
                </div>
                <div className="text-sm" style={{ color: "var(--on-surface-variant)" }}>
                  {t("activeClients")}
                </div>
                <div className="mt-4">
                  <span className="text-lg font-bold">{formatHuf(plan.monthlyPriceHuf)}</span>
                  <span className="text-sm" style={{ color: "var(--muted)" }}>{t("perMonth")}</span>
                </div>
                <div
                  className="inline-flex h-7 items-center px-2.5 rounded-pill text-[11px] font-bold mt-2"
                  style={{ background: "var(--surface-container)", color: "var(--on-surface-variant)" }}
                >
                  {t("trial14")}
                </div>
                <ul className="flex flex-col gap-2.5 mt-5">
                  {[t("bulletAllFeatures"), bullet2, t("bulletScheduling")].map((b) => (
                    <li key={b} className="flex gap-2 items-start text-sm">
                      <span
                        className="material-symbols-rounded text-lg mt-0.5"
                        style={{ color: "var(--primary)", fontVariationSettings: "'FILL' 1" }}
                      >
                        check_circle
                      </span>
                      {b}
                    </li>
                  ))}
                </ul>
                <TrackedCta
                  href={pricingHref}
                  page={page}
                  slot={`pricing-${plan.id}`}
                  audience="trainer"
                  className="flex h-12 items-center justify-center rounded-pill text-sm font-extrabold mt-6"
                  style={
                    plan.recommended
                      ? { background: "var(--primary)", color: "var(--bg)" }
                      : { border: "1.5px solid var(--outline)" }
                  }
                >
                  {t("planCta")}
                </TrackedCta>
              </div>
            );
          })}
        </div>

        <div className="text-center mt-8">
          <Link
            href={{ pathname: "/pricing", query: { src: `${page}-pricing-preview-link` } }}
            className="text-sm font-bold"
            style={{ color: "var(--primary)" }}
          >
            {t("cta")}
          </Link>
        </div>
      </div>
    </section>
  );
}
