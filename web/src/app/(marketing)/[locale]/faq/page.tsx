import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { buildMetadata } from "@/lib/marketingMetadata";

// The full FAQ page (docs/landing_page/65 Prompt 8, 68 §6: "a two-column
// layout on desktop (category rail + content), single column mobile").
// Reuses the exact Q&A already shipped on the home page (Prompt 4) and the
// pricing page's billing FAQ (Prompt 6) where the topic already has
// verified copy, rather than retyping it — see this page's own category
// list below for which items are reused vs. new. The rail is a plain
// sticky anchor-link list (CSS `position: sticky`, no JS) rather than a
// client-side tab switcher — consistent with every other marketing page
// staying a Server Component unless real interactivity is unavoidable
// (65 Prompt 6 is still the only page that needed a client island).
export const dynamic = "force-static";

type Item = { q: string; a: string };
type Category = { id: string; label: string; items: Item[] };

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "seo.faq" });
  return buildMetadata({ locale, href: "/faq", title: t("metaTitle"), description: t("metaDescription") });
}

export default async function FaqPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  const t = await getTranslations("faq");
  const home = await getTranslations("home.faq");
  const pricing = await getTranslations("pricing");

  const categories: Category[] = [
    {
      id: "general",
      label: t("categoryGeneral"),
      items: [1, 2, 3, 4].map((n) => ({
        q: t(`general${n}Q` as "general1Q"),
        a: t(`general${n}A` as "general1A"),
      })),
    },
    {
      id: "trainers",
      label: t("categoryTrainers"),
      items: [
        { q: home("q1"), a: home("a1") },
        { q: home("q2"), a: home("a2") },
        { q: pricing("faqQ1"), a: pricing("faqA1") },
        { q: pricing("faqQ2"), a: pricing("faqA2") },
        { q: pricing("faqQ3"), a: pricing("faqA3") },
        { q: pricing("faqQ4"), a: pricing("faqA4") },
        { q: pricing("faqQ5"), a: pricing("faqA5") },
        { q: pricing("faqQ6"), a: pricing("faqA6") },
        { q: home("q5"), a: home("a5") },
      ],
    },
    {
      id: "clients",
      label: t("categoryClients"),
      items: [
        { q: home("q4"), a: home("a4") },
        { q: t("clients2Q"), a: t("clients2A") },
        { q: t("clients3Q"), a: t("clients3A") },
        { q: t("clients4Q"), a: t("clients4A") },
      ],
    },
    {
      id: "technical",
      label: t("categoryTechnical"),
      items: [1, 2, 3].map((n) => ({
        q: t(`technical${n}Q` as "technical1Q"),
        a: t(`technical${n}A` as "technical1A"),
      })),
    },
  ];

  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: categories.flatMap((cat) =>
      cat.items.map((item) => ({
        "@type": "Question",
        name: item.q,
        acceptedAnswer: { "@type": "Answer", text: item.a },
      }))
    ),
  };

  return (
    <main className="py-14 md:py-20" style={{ background: "var(--bg)" }}>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />

      <div className="max-w-[1000px] mx-auto px-4 md:px-8">
        <h1 className="text-[32px] md:text-[44px] font-bold tracking-[-0.02em] text-center">{t("title")}</h1>
        <p className="text-base md:text-lg mt-3 text-center max-w-[62ch] mx-auto" style={{ color: "var(--on-surface-variant)" }}>
          {t("sub")}
        </p>

        <div className="grid md:grid-cols-[180px_1fr] gap-8 md:gap-12 mt-10 md:mt-14">
          <nav className="hidden md:block" aria-label={t("title")}>
            <div className="sticky top-24 flex flex-col gap-1">
              {categories.map((cat) => (
                <a
                  key={cat.id}
                  href={`#${cat.id}`}
                  className="text-sm font-bold py-2 border-l-2 pl-3.5"
                  style={{ borderColor: "var(--outline)", color: "var(--on-surface-variant)" }}
                >
                  {cat.label}
                </a>
              ))}
            </div>
          </nav>

          <div className="flex flex-col gap-10 md:gap-12">
            {categories.map((cat) => (
              <section key={cat.id} id={cat.id} className="scroll-mt-24">
                <h2 className="text-xl md:text-2xl font-bold">{cat.label}</h2>
                <div className="flex flex-col gap-3 mt-4">
                  {cat.items.map((item) => (
                    <details
                      key={item.q}
                      className="group rounded-lg border border-outline px-5 py-4"
                      style={{ background: "var(--surface-container)" }}
                    >
                      <summary className="flex items-center gap-4 cursor-pointer list-none">
                        <span className="text-base font-bold flex-1">{item.q}</span>
                        <span
                          className="material-symbols-rounded text-2xl shrink-0 transition-transform duration-150 group-open:rotate-180"
                          style={{ color: "var(--primary)" }}
                        >
                          expand_more
                        </span>
                      </summary>
                      <p className="text-sm leading-[1.6] mt-3 max-w-[62ch]" style={{ color: "var(--on-surface-variant)" }}>
                        {item.a}
                      </p>
                    </details>
                  ))}
                </div>
              </section>
            ))}
          </div>
        </div>
      </div>
    </main>
  );
}
