import { getTranslations } from "next-intl/server";

/**
 * 68 §13.1: "a 'day in the life' strip" — no frame exists, so this reuses
 * HowItWorks.tsx's connected-card vocabulary (numbered circle, outline
 * connector, surface-container card) with a time-of-day badge instead of
 * an ordinal, rather than inventing a new visual pattern. Four moments,
 * each naming a feature already shown earlier on this page (program edit,
 * chat with workout context, the weekly report) — not new claims.
 */
export async function DayInLifeStrip() {
  const t = await getTranslations("forTrainers.dayInLife");

  const items = [1, 2, 3, 4].map((n) => ({
    time: t(`item${n}Time` as "item1Time"),
    title: t(`item${n}Title` as "item1Title"),
    body: t(`item${n}Body` as "item1Body"),
  }));

  return (
    <section className="py-16 md:py-24" style={{ background: "var(--surface-container)" }}>
      <div className="max-w-[1200px] mx-auto px-4 md:px-8">
        <h2 className="text-[28px] md:text-[44px] font-bold tracking-[-0.02em] max-w-[20ch]">{t("title")}</h2>
        <div className="grid md:grid-cols-4 gap-5 md:gap-5 mt-8 md:mt-11 relative">
          <div
            className="hidden md:block absolute top-[22px] left-[12.5%] right-[12.5%] h-px"
            style={{ background: "var(--outline)" }}
            aria-hidden
          />
          {items.map((item) => (
            <div key={item.time} className="rounded-lg p-5 md:p-6 relative" style={{ background: "var(--bg)" }}>
              <div
                className="h-11 px-3.5 rounded-pill flex items-center justify-center text-sm font-extrabold tabular-nums relative w-fit"
                style={{ background: "var(--primary)", color: "var(--bg)" }}
              >
                {item.time}
              </div>
              <h3 className="text-base md:text-lg font-bold mt-4">{item.title}</h3>
              <p className="text-sm leading-[1.55] mt-2" style={{ color: "var(--on-surface-variant)" }}>
                {item.body}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
