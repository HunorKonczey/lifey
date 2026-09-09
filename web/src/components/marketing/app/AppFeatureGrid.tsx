import { getTranslations } from "next-intl/server";

/**
 * 68 §6: "a feature grid" with "--secondary accent throughout" (unlike the
 * home page's FeatureGrid.tsx, where one card is --primary). Same card
 * vocabulary, all-tan accent, and content grounded in the real free-tier
 * feature table (63 D-M5) rather than the home grid's trainer-adjacent
 * items (no "calendar_month" scheduling card here — that's the trainer
 * workspace's story, not the individual app's).
 */
export async function AppFeatureGrid() {
  const t = await getTranslations("app.features");

  const features = [
    { icon: "restaurant", title: t("nutritionTitle"), body: t("nutritionBody") },
    { icon: "fitness_center", title: t("workoutsTitle"), body: t("workoutsBody") },
    { icon: "directions_run", title: t("cardioTitle"), body: t("cardioBody") },
    { icon: "watch", title: t("watchTitle"), body: t("watchBody") },
    { icon: "cloud_off", title: t("offlineTitle"), body: t("offlineBody") },
    { icon: "smart_toy", title: t("aiTitle"), body: t("aiBody") },
    { icon: "favorite", title: t("healthTitle"), body: t("healthBody") },
    { icon: "widgets", title: t("widgetsTitle"), body: t("widgetsBody") },
    { icon: "translate", title: t("langTitle"), body: t("langBody") },
  ];

  return (
    <section className="py-16 md:py-24" style={{ background: "var(--surface-container)" }}>
      <div className="max-w-[1200px] mx-auto px-4 md:px-8">
        <h2 className="text-[28px] md:text-[44px] font-bold tracking-[-0.02em] max-w-[18ch]">{t("title")}</h2>
        <p className="text-base md:text-xl mt-2.5 md:mt-3.5 max-w-[62ch]" style={{ color: "var(--on-surface-variant)" }}>
          {t("sub")}
        </p>

        <div className="grid md:grid-cols-3 gap-3.5 md:gap-5 mt-8 md:mt-10">
          {features.map((f) => (
            <div
              key={f.title}
              className="rounded-lg border border-outline p-4 md:p-6 flex md:block gap-3"
              style={{ background: "var(--bg)" }}
            >
              <span
                className="material-symbols-rounded text-2xl md:text-[28px] shrink-0"
                style={{ color: "var(--secondary)", fontVariationSettings: "'FILL' 1" }}
              >
                {f.icon}
              </span>
              <div>
                <div className="text-base md:text-[19px] font-bold md:mt-3.5">{f.title}</div>
                <p
                  className="text-sm md:text-[15px] leading-[1.5] md:leading-[1.55] mt-0.5 md:mt-1.5"
                  style={{ color: "var(--on-surface-variant)" }}
                >
                  {f.body}
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
