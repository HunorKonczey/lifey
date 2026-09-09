import { getTranslations } from "next-intl/server";

function PhoneFrame({ children, label }: { children: React.ReactNode; label: string }) {
  return (
    <div className="shrink-0 snap-center" style={{ scrollSnapAlign: "center" }}>
      <div
        className="w-[190px] h-[380px] rounded-3xl overflow-hidden border-[6px] flex flex-col"
        style={{ background: "var(--bg)", borderColor: "var(--surface-high)", boxShadow: "0 20px 44px rgba(0,0,0,.3)" }}
      >
        <div className="h-5 flex items-center justify-center shrink-0" style={{ background: "var(--surface-container)" }}>
          <div className="w-11 h-1.5 rounded-pill" style={{ background: "var(--outline)" }} />
        </div>
        <div className="flex-1 p-3 overflow-hidden">{children}</div>
      </div>
      <div className="text-center text-[13px] font-bold mt-3" style={{ color: "var(--on-surface-variant)" }}>
        {label}
      </div>
    </div>
  );
}

/**
 * 68 §6: "a screenshot carousel that is a scroll-snap row, not a JS
 * carousel" — `overflow-x-auto` + `scroll-snap-type`, zero JS. Five
 * reproduced screens (D-DW1: real UI at marketing scale, not photography —
 * no seeded demo backend exists to capture real screenshots from, same
 * reasoning as the home page's mockups, 65 Prompt 4 landed note 1),
 * covering the five pillars 65 §4 names for this page: nutrition,
 * workouts, cardio, watch, offline.
 */
export async function AppScreenshotRow() {
  const t = await getTranslations("app.screenshots");
  const demo = await getTranslations("home.demo");

  return (
    <section className="py-16 md:py-20" style={{ background: "var(--bg)" }}>
      <div className="max-w-[1200px] mx-auto px-4 md:px-8">
        <h2 id="app-screenshots-heading" className="text-[28px] md:text-[44px] font-bold tracking-[-0.02em] max-w-[18ch]">
          {t("title")}
        </h2>
      </div>

      {/* `tabIndex`/`role`/`aria-labelledby`: a horizontally scrollable region
          with no focusable children can only be scrolled with a pointer, which
          is axe's `scrollable-region-focusable` (WCAG 2.1.1) — the phones in
          this row are static markup, so without this a keyboard user reaches
          the first frame and no further (docs/landing_page/72 W4). Labelled by
          the section's own heading rather than a new string. */}
      <div
        tabIndex={0}
        role="group"
        aria-labelledby="app-screenshots-heading"
        className="flex gap-6 md:gap-8 overflow-x-auto pt-8 pb-4 px-4 md:px-8 mt-2"
        style={{ scrollSnapType: "x mandatory" }}
      >
        <PhoneFrame label={t("nutritionLabel")}>
          <div className="text-[10px] font-bold" style={{ color: "var(--muted)" }}>{t("nutritionToday").toUpperCase()}</div>
          <div className="text-xl font-extrabold tabular-nums mt-0.5">1 840 <span className="text-xs font-semibold" style={{ color: "var(--muted)" }}>/ 2 200 kcal</span></div>
          <div className="h-2 rounded-pill mt-2" style={{ background: "var(--outline)" }}>
            <div className="h-2 rounded-pill w-4/5" style={{ background: "var(--secondary)" }} />
          </div>
          <div className="flex flex-col gap-1.5 mt-3">
            {[t("nutritionBreakfast"), t("nutritionLunch")].map((m) => (
              <div key={m} className="rounded-md p-2" style={{ background: "var(--surface-container)" }}>
                <div className="text-[11px] font-bold">{m}</div>
              </div>
            ))}
          </div>
        </PhoneFrame>

        <PhoneFrame label={t("workoutsLabel")}>
          <div className="text-[13px] font-extrabold">{t("workoutsType")}</div>
          <div className="text-[10px]" style={{ color: "var(--muted)" }}>{t("workoutsWeek")}</div>
          <div className="flex flex-col gap-1.5 mt-2.5">
            {[demo("squat"), demo("benchPress")].map((ex) => (
              <div key={ex} className="rounded-md p-2 flex justify-between" style={{ background: "var(--surface-container)" }}>
                <span className="text-[11px] font-bold">{ex}</span>
                <span className="text-[10.5px] tabular-nums" style={{ color: "var(--muted)" }}>5×5</span>
              </div>
            ))}
          </div>
          <div className="h-9 rounded-pill flex items-center justify-center text-xs font-extrabold mt-3" style={{ background: "var(--secondary)", color: "var(--bg)" }}>
            {t("workoutsStart")}
          </div>
        </PhoneFrame>

        <PhoneFrame label={t("cardioLabel")}>
          <div className="text-[10px] font-bold" style={{ color: "var(--muted)" }}>{t("cardioType").toUpperCase()}</div>
          <div className="text-xl font-extrabold tabular-nums mt-0.5">6,2 <span className="text-xs font-semibold" style={{ color: "var(--muted)" }}>km</span></div>
          <div className="grid grid-cols-2 gap-1.5 mt-2.5">
            <div className="rounded-md p-2" style={{ background: "var(--surface-container)" }}>
              <div className="text-[9.5px] font-bold" style={{ color: "var(--muted)" }}>{t("cardioPace").toUpperCase()}</div>
              <div className="text-sm font-extrabold tabular-nums">5:12</div>
            </div>
            <div className="rounded-md p-2" style={{ background: "var(--surface-container)" }}>
              <div className="text-[9.5px] font-bold" style={{ color: "var(--muted)" }}>{t("cardioTime").toUpperCase()}</div>
              <div className="text-sm font-extrabold tabular-nums">32:08</div>
            </div>
          </div>
        </PhoneFrame>

        <PhoneFrame label={t("watchLabel")}>
          <div className="text-[10px] font-bold" style={{ color: "var(--muted)" }}>{t("watchToday").toUpperCase()}</div>
          <div className="text-[15px] font-extrabold mt-1">{demo("squat")}</div>
          <div className="rounded-md p-2 mt-2" style={{ background: "var(--surface-container)" }}>
            <div className="text-[10.5px] font-bold">5×5 · 82,5 kg</div>
          </div>
          <div className="h-8 rounded-pill flex items-center justify-center text-[11px] font-extrabold mt-2.5" style={{ background: "var(--secondary)", color: "var(--bg)" }}>
            {t("watchNextSet")}
          </div>
        </PhoneFrame>

        <PhoneFrame label={t("offlineLabel")}>
          <div className="flex items-center gap-1.5">
            <span className="material-symbols-rounded text-base" style={{ color: "var(--muted)" }}>cloud_off</span>
            <div className="text-[10.5px] font-bold" style={{ color: "var(--muted)" }}>{t("offlineBadge")}</div>
          </div>
          <div className="rounded-md p-2 mt-2.5" style={{ background: "var(--surface-container)" }}>
            <div className="text-[11px] font-bold">{demo("squat")}</div>
            <div className="text-[10px] tabular-nums" style={{ color: "var(--muted)" }}>5×5 · 82,5 kg</div>
          </div>
          <div className="text-[10.5px] leading-[1.5] mt-2.5" style={{ color: "var(--on-surface-variant)" }}>
            {t("offlineNote")}
          </div>
        </PhoneFrame>
      </div>
    </section>
  );
}
