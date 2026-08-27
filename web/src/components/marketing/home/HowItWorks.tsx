import { getTranslations } from "next-intl/server";

/** design/Lifey Landing.dc.html L16 — step 1 states the manual review honestly (66 D-T1). */
export async function HowItWorks() {
  const t = await getTranslations("home.howItWorks");

  const steps = [
    {
      title: t("step1Title"),
      body: t("step1Body"),
      calloutBold: t("step1CalloutBold"),
      calloutRest: t("step1CalloutRest"),
    },
    { title: t("step2Title"), body: t("step2Body") },
    { title: t("step3Title"), body: t("step3Body") },
  ];

  return (
    <section className="py-16 md:py-24" style={{ background: "var(--bg)" }}>
      <div className="max-w-[1200px] mx-auto px-4 md:px-8">
        <h2 className="text-[28px] md:text-[44px] font-bold tracking-[-0.02em] max-w-[18ch]">{t("title")}</h2>
        <div className="grid md:grid-cols-3 gap-5 md:gap-7 mt-8 md:mt-11 relative">
          <div
            className="hidden md:block absolute top-[22px] left-[16.6%] right-[16.6%] h-px"
            style={{ background: "var(--outline)" }}
            aria-hidden
          />
          {steps.map((step, i) => (
            <div
              key={step.title}
              className="rounded-lg p-6 md:p-7 relative"
              style={{ background: "var(--surface-container)" }}
            >
              <div
                className="w-11 h-11 rounded-pill flex items-center justify-center text-lg font-extrabold tabular-nums relative"
                style={{ background: "var(--primary)", color: "#161611" }}
              >
                {i + 1}
              </div>
              <h3 className="text-xl md:text-[22px] font-bold mt-4.5">{step.title}</h3>
              <p className="text-base leading-[1.6] mt-2.5" style={{ color: "var(--on-surface-variant)" }}>
                {step.body}
              </p>
              {step.calloutBold && (
                <div
                  className="rounded-md border border-outline p-3.5 mt-4 flex gap-2.5"
                  style={{ background: "var(--bg)" }}
                >
                  <span
                    className="material-symbols-rounded text-xl shrink-0"
                    style={{ color: "var(--secondary)" }}
                  >
                    schedule
                  </span>
                  <p className="text-sm leading-[1.55]">
                    <b>{step.calloutBold}</b>
                    {step.calloutRest}
                  </p>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
