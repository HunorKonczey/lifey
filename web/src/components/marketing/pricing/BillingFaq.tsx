import { getTranslations } from "next-intl/server";

/**
 * 68 §5.4 ("six <details> items") — not drawn in the delivered canvas (L19
 * has no FAQ block at all, unlike the frame map's §5 reference implies),
 * so this reuses FaqPreview.tsx's native <details>/<summary> vocabulary
 * rather than a new pattern. Topics straight from §5.4: trial end, cancel,
 * what happens to clients, invoice, changing plans, VAT.
 */
export async function BillingFaq() {
  const t = await getTranslations("pricing");

  const items = [1, 2, 3, 4, 5, 6].map((n) => ({
    q: t(`faqQ${n}` as "faqQ1"),
    a: t(`faqA${n}` as "faqA1"),
  }));

  return (
    <section className="py-16 md:py-20" style={{ background: "var(--surface-container)" }}>
      <div className="max-w-[1200px] mx-auto px-4 md:px-8">
        <h2 className="text-[28px] md:text-[44px] font-bold tracking-[-0.02em]">{t("billingFaqTitle")}</h2>
        <div className="flex flex-col gap-3 mt-7 md:mt-9 max-w-[820px]">
          {items.map((item) => (
            <details
              key={item.q}
              className="group rounded-lg border border-outline px-5 py-4 md:px-6.5 md:py-6"
              style={{ background: "var(--bg)" }}
            >
              <summary className="flex items-center gap-4 cursor-pointer list-none">
                <span className="text-base md:text-[19px] font-bold flex-1">{item.q}</span>
                <span
                  className="material-symbols-rounded text-2xl md:text-[26px] shrink-0 transition-transform duration-150 group-open:rotate-180"
                  style={{ color: "var(--primary)" }}
                >
                  expand_more
                </span>
              </summary>
              <p
                className="text-sm md:text-base leading-[1.6] md:leading-[1.65] mt-3 max-w-[62ch]"
                style={{ color: "var(--on-surface-variant)" }}
              >
                {item.a}
              </p>
            </details>
          ))}
        </div>
      </div>
    </section>
  );
}
