import { getTranslations } from "next-intl/server";

/** design/Lifey Landing.dc.html L17 (desktop, 3×3) / L18 (mobile, 1 column). */
export async function FeatureGrid() {
  const t = await getTranslations("home.featureGrid");

  const features = [
    { icon: "calendar_month", accent: "primary", title: t("calendarTitle"), body: t("calendarBody"), bodyMobile: t("calendarBodyMobile") },
    { icon: "insights", accent: "secondary", title: t("statsTitle"), body: t("statsBody"), bodyMobile: t("statsBodyMobile") },
    { icon: "emoji_events", accent: "secondary", title: t("prTitle"), body: t("prBody"), bodyMobile: t("prBodyMobile") },
    { icon: "directions_run", accent: "secondary", title: t("cardioTitle"), body: t("cardioBody"), bodyMobile: t("cardioBodyMobile") },
    { icon: "watch", accent: "secondary", title: t("watchTitle"), body: t("watchBody"), bodyMobile: t("watchBodyMobile") },
    { icon: "cloud_off", accent: "secondary", title: t("offlineTitle"), body: t("offlineBody"), bodyMobile: t("offlineBodyMobile") },
    { icon: "translate", accent: "secondary", title: t("langTitle"), body: t("langBody"), bodyMobile: t("langBodyMobile") },
    { icon: "favorite", accent: "secondary", title: t("healthTitle"), titleMobile: t("healthTitleMobile"), body: t("healthBody"), bodyMobile: t("healthBodyMobile") },
    { icon: "widgets", accent: "secondary", title: t("widgetsTitle"), body: t("widgetsBody"), bodyMobile: t("widgetsBodyMobile") },
  ];

  return (
    <section className="py-16 md:py-24" style={{ background: "var(--surface-container)" }}>
      <div className="max-w-[1200px] mx-auto px-4 md:px-8">
        <h2 className="hidden md:block text-[44px] font-bold tracking-[-0.02em]">{t("title")}</h2>
        <p className="hidden md:block text-xl mt-3.5 max-w-[62ch]" style={{ color: "var(--on-surface-variant)" }}>
          {t("sub")}
        </p>
        <h2 className="md:hidden text-[28px] font-bold tracking-[-0.02em] leading-[1.14]">{t("titleMobile")}</h2>
        <p className="md:hidden text-[17px] mt-2.5" style={{ color: "var(--on-surface-variant)" }}>
          {t("subMobile")}
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
                style={{ color: `var(--${f.accent})`, fontVariationSettings: "'FILL' 1" }}
              >
                {f.icon}
              </span>
              <div>
                <div className="text-base md:text-[19px] font-bold md:mt-3.5">
                  {f.titleMobile ? <span className="md:hidden">{f.titleMobile}</span> : null}
                  <span className={f.titleMobile ? "hidden md:inline" : ""}>{f.title}</span>
                </div>
                <p className="text-sm md:text-[15px] leading-[1.5] md:leading-[1.55] mt-0.5 md:mt-1.5" style={{ color: "var(--on-surface-variant)" }}>
                  <span className="hidden md:inline">{f.body}</span>
                  <span className="md:hidden">{f.bodyMobile}</span>
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
