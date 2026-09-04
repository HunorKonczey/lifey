import { getLocale, getTranslations } from "next-intl/server";
import { getPathname } from "@/i18n/navigation";
import { TrackedCta } from "../TrackedCta";
import { BrowserWindowFrame } from "./BrowserWindowFrame";

// `fg` is per-entry because the palette is mixed: --secondary/--tertiary
// flip with the theme (dark in light mode, so they need the light --bg on
// top), while the two literal pastels are the same in both themes and keep
// the near-black they were picked against.
const AVATARS = [
  { initials: "SZ", bg: "var(--secondary)", fg: "var(--bg)" },
  { initials: "TM", bg: "var(--tertiary)", fg: "var(--bg)" },
  { initials: "NR", bg: "#8AA0B4", fg: "#161611" },
  { initials: "KD", bg: "#B08AC8", fg: "#161611" },
];

/**
 * design/Lifey Landing.dc.html L04 (dark HU) / L05 (light EN) / L06 (mobile).
 * One implementation for both themes — the mockup panel uses the same CSS
 * custom properties as the real /admin UI, so it themes for free.
 */
export async function Hero() {
  const t = await getTranslations("home.hero");
  const demo = await getTranslations("home.demo");
  const locale = await getLocale();

  return (
    <section className="pt-10 md:pt-16 pb-14 md:pb-20" style={{ background: "var(--bg)" }}>
      <div className="max-w-[1200px] mx-auto px-4 md:px-8 grid md:grid-cols-12 gap-10 md:gap-12 items-center">
        <div className="md:col-span-7">
          <div
            className="inline-flex items-center gap-2 h-8 px-3.5 rounded-pill text-[12.5px] font-extrabold tracking-wide"
            style={{ background: "var(--surface-container)", color: "var(--primary)" }}
          >
            <span className="material-symbols-rounded text-base" style={{ fontVariationSettings: "'FILL' 1" }}>
              workspace_premium
            </span>
            {t("eyebrow").toUpperCase()}
          </div>
          <h1
            className="text-[36px] md:text-[64px] font-extrabold tracking-[-0.02em] leading-[1.06] md:leading-[1.04] mt-4 max-w-[18ch]"
          >
            {t("title")}
          </h1>
          <p
            className="hidden md:block text-xl font-medium leading-[1.6] mt-5 max-w-[62ch]"
            style={{ color: "var(--on-surface-variant)" }}
          >
            {t("sub")}
          </p>
          <p
            className="md:hidden text-[17px] font-medium leading-[1.55] mt-3.5"
            style={{ color: "var(--on-surface-variant)" }}
          >
            {t("subMobile")}
          </p>

          <div className="flex flex-col md:flex-row gap-3.5 mt-7 md:mt-8">
            <TrackedCta
              href="/register"
              page="home"
              slot="hero-primary"
              audience="trainer"
              className="h-14 rounded-pill flex items-center justify-center md:justify-start px-7.5 text-base font-extrabold"
              style={{ background: "var(--primary)", color: "var(--bg)" }}
            >
              {t("ctaPrimary")}
            </TrackedCta>
            <TrackedCta
              href={getPathname({ locale, href: "/pricing" })}
              page="home"
              slot="hero-secondary"
              audience="trainer"
              className="h-14 rounded-pill flex items-center justify-center md:justify-start px-7.5 text-base font-bold border-[1.5px] border-outline"
            >
              {t("ctaSecondary")}
            </TrackedCta>
          </div>

          <div
            className="flex items-center gap-2.5 mt-4 md:mt-5 text-sm font-semibold"
            style={{ color: "var(--muted)" }}
          >
            <span className="material-symbols-rounded text-lg" style={{ color: "var(--tertiary)", fontVariationSettings: "'FILL' 1" }}>
              check_circle
            </span>
            <span className="hidden md:inline">
              {t("reassurance")}
              <span style={{ color: "var(--outline)" }}> · </span>
              <span style={{ color: "var(--secondary)" }}>{t("reassuranceHighlight")}</span>
            </span>
            <span className="md:hidden">
              {t("reassurance")}
              <br />
              <span style={{ color: "var(--secondary)" }}>{t("reassuranceHighlight")}</span>
            </span>
          </div>
        </div>

        <div className="md:col-span-5 relative">
          <div className="hidden md:block relative h-[420px]">
            <div className="absolute left-0 top-0 -right-15 w-[calc(100%+60px)]">
              <BrowserWindowFrame url="lifey.hu/admin/clients">
                <div className="flex h-[340px]">
                  <div
                    className="w-14 py-3 flex flex-col items-center gap-3.5"
                    style={{ background: "var(--surface-container)" }}
                  >
                    <span
                      className="w-[30px] h-[30px] rounded-md flex items-center justify-center"
                      style={{ background: "var(--primary)", color: "var(--bg)" }}
                    >
                      <span className="material-symbols-rounded text-lg" style={{ fontVariationSettings: "'FILL' 1" }}>
                        eco
                      </span>
                    </span>
                    <span className="material-symbols-rounded text-[21px]" style={{ color: "var(--primary)", fontVariationSettings: "'FILL' 1" }}>groups</span>
                    <span className="material-symbols-rounded text-[21px]" style={{ color: "var(--muted)" }}>assignment</span>
                    <span className="material-symbols-rounded text-[21px]" style={{ color: "var(--muted)" }}>calendar_month</span>
                    <span className="material-symbols-rounded text-[21px]" style={{ color: "var(--muted)" }}>chat</span>
                    <span className="material-symbols-rounded text-[21px]" style={{ color: "var(--muted)" }}>insights</span>
                  </div>
                  <div className="flex-1 p-4">
                    <div className="flex items-center justify-between">
                      <div className="text-base font-extrabold">
                        {t("mockClientsHeading")}{" "}
                        <span className="font-semibold tabular-nums" style={{ color: "var(--muted)" }}>12</span>
                      </div>
                      <div
                        className="h-[26px] flex items-center px-3 rounded-pill text-[11px] font-extrabold"
                        style={{ background: "var(--primary)", color: "var(--bg)" }}
                      >
                        {t("mockInvite")}
                      </div>
                    </div>
                    <div className="flex flex-col gap-1.5 mt-3">
                      {[
                        { name: "Szabó Anna", meta: demo("strength"), badge: "4/4", ok: true },
                        { name: "Tóth Márk", meta: demo("fatLoss"), badge: "2/4", ok: false },
                        { name: "Nagy Réka", meta: demo("hypertrophy"), badge: "3/3", ok: true },
                        { name: "Kiss Dávid", meta: demo("invited"), badge: "", ok: null },
                      ].map((row, i) => (
                        <div
                          key={row.name}
                          className="flex items-center gap-2.5 rounded-md px-2.5 py-2.5"
                          style={{ background: "var(--surface-container)" }}
                        >
                          <span
                            className="w-[30px] h-[30px] rounded-pill flex items-center justify-center text-[11px] font-extrabold"
                            style={{ background: AVATARS[i].bg, color: AVATARS[i].fg }}
                          >
                            {AVATARS[i].initials}
                          </span>
                          <div className="flex-1">
                            <div className="text-xs font-bold">{row.name}</div>
                            <div className="text-[10.5px]" style={{ color: "var(--muted)" }}>{row.meta}</div>
                          </div>
                          <div
                            className="text-[11px] font-extrabold tabular-nums"
                            style={{ color: row.ok === null ? "var(--muted)" : row.ok ? "var(--tertiary)" : "var(--secondary)" }}
                          >
                            {row.badge}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </BrowserWindowFrame>
            </div>

            <div
              className="absolute -left-7.5 -bottom-10 w-[170px] rounded-3xl overflow-hidden border-[6px]"
              style={{ background: "var(--bg)", borderColor: "var(--surface-high)", boxShadow: "0 20px 44px rgba(0,0,0,.35)" }}
            >
              <div className="h-4.5 flex items-center justify-center" style={{ background: "var(--surface-container)" }}>
                <div className="w-11 h-1.5 rounded-pill" style={{ background: "var(--outline)" }} />
              </div>
              <div className="p-2.5">
                <div className="text-[10px] font-bold" style={{ color: "var(--muted)" }}>{t("mockWatchDay")}</div>
                <div className="text-[15px] font-extrabold mb-2">{t("mockWatchTitle")}</div>
                <div className="rounded-md p-2 mb-1.5" style={{ background: "var(--surface-container)" }}>
                  <div className="text-[10.5px] font-bold">{demo("squat")}</div>
                  <div className="text-[9.5px] tabular-nums" style={{ color: "var(--muted)" }}>5×5 · 82,5 kg</div>
                </div>
                <div className="rounded-md p-2 mb-1.5" style={{ background: "var(--surface-container)" }}>
                  <div className="text-[10.5px] font-bold">{demo("benchPress")}</div>
                  <div className="text-[9.5px] tabular-nums" style={{ color: "var(--muted)" }}>5×5 · 65 kg</div>
                </div>
                <div
                  className="h-7.5 rounded-pill flex items-center justify-center text-[11px] font-extrabold"
                  style={{ background: "var(--primary)", color: "var(--bg)" }}
                >
                  {t("mockWatchStart")}
                </div>
              </div>
            </div>
          </div>

          {/* Mobile: the phone mock alone, centred */}
          <div className="md:hidden flex justify-center mt-2">
            <div
              className="w-[220px] rounded-3xl overflow-hidden border-[6px]"
              style={{ background: "var(--bg)", borderColor: "var(--surface-high)", boxShadow: "0 20px 44px rgba(0,0,0,.35)" }}
            >
              <div className="h-5 flex items-center justify-center" style={{ background: "var(--surface-container)" }}>
                <div className="w-12 h-1.5 rounded-pill" style={{ background: "var(--outline)" }} />
              </div>
              <div className="p-3">
                <div className="text-[11px] font-bold" style={{ color: "var(--muted)" }}>{t("mockWatchDay")}</div>
                <div className="text-base font-extrabold mb-2.5">{t("mockWatchTitle")}</div>
                <div className="rounded-md p-2.5 mb-2" style={{ background: "var(--surface-container)" }}>
                  <div className="text-xs font-bold">{demo("squat")}</div>
                  <div className="text-[10.5px] tabular-nums" style={{ color: "var(--muted)" }}>5×5 · 82,5 kg</div>
                </div>
                <div
                  className="h-9 rounded-pill flex items-center justify-center text-xs font-extrabold"
                  style={{ background: "var(--primary)", color: "var(--bg)" }}
                >
                  {t("mockWatchStart")}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
