import { getTranslations } from "next-intl/server";

/**
 * design/Lifey Landing.dc.html L08 — variant "B" (fallback) only. The
 * numbers version ("A") does not ship until there are real figures (68
 * §4.3): a proof strip with invented numbers is worse than none. The
 * component takes an optional `stats` prop so plugging in the real version
 * later is a data change, not a rewrite — but nothing calls it with stats
 * yet, and nothing should until the numbers are real.
 */
export async function ProofStrip({
  stats,
}: {
  stats?: { trainers: string; clients: string; sessions: string; rating: string };
}) {
  const t = await getTranslations("home.proof");

  if (stats) {
    // Reserved for when real numbers exist — not used today.
    return (
      <section className="py-14 md:py-16" style={{ background: "var(--bg)" }}>
        <div className="max-w-[1200px] mx-auto px-4 md:px-8 grid grid-cols-2 md:grid-cols-4 gap-6 md:gap-8">
          {Object.values(stats).map((v, i) => (
            <div key={i} className="text-[28px] md:text-[44px] font-extrabold tracking-[-0.02em] tabular-nums">
              {v}
            </div>
          ))}
        </div>
      </section>
    );
  }

  return (
    <section className="py-12 md:py-14" style={{ background: "var(--bg)" }}>
      <div className="max-w-[1200px] mx-auto px-4 md:px-8">
        <p
          className="text-lg md:text-xl font-medium leading-[1.6] max-w-[62ch]"
          style={{ color: "var(--on-surface-variant)" }}
        >
          {t("fallback")}
        </p>
      </div>
    </section>
  );
}
