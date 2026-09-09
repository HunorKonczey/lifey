import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";

/**
 * design/Lifey Landing.dc.html L21 (top half) — native <details>/<summary>,
 * no JS, no layout shift, keyboard-accessible for free (68 §4.11). Only the
 * first item is open by default, matching the frame.
 */
export async function FaqPreview() {
  const t = await getTranslations("home.faq");

  const items = [1, 2, 3, 4, 5].map((n) => ({
    q: t(`q${n}` as "q1"),
    a: t(`a${n}` as "a1"),
  }));

  return (
    <section className="py-16 md:py-20" style={{ background: "var(--surface-container)" }}>
      <div className="max-w-[1200px] mx-auto px-4 md:px-8">
        <h2 className="text-[28px] md:text-[44px] font-bold tracking-[-0.02em]">{t("title")}</h2>
        <div className="flex flex-col gap-3 mt-7 md:mt-9 max-w-[820px]">
          {items.map((item, i) => (
            <details
              key={item.q}
              open={i === 0}
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
        <div className="mt-6">
          <Link
            href={{ pathname: "/faq", query: { src: "home-faq-preview" } }}
            className="text-sm font-bold"
            style={{ color: "var(--primary)" }}
          >
            {t("linkToFull")}
          </Link>
        </div>
      </div>
    </section>
  );
}
