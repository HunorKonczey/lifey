import { getLocale, getTranslations } from "next-intl/server";
import { getPathname } from "@/i18n/navigation";
import { TrackedCta } from "../TrackedCta";

function BottomNav() {
  return (
    <div className="flex justify-around border-t border-outline py-2.5" style={{ background: "var(--surface)" }}>
      <span className="material-symbols-rounded text-[22px]" style={{ color: "var(--primary)", fontVariationSettings: "'FILL' 1" }}>home</span>
      <span className="material-symbols-rounded text-[22px]" style={{ color: "var(--muted)" }}>restaurant</span>
      <span className="material-symbols-rounded text-[22px]" style={{ color: "var(--muted)" }}>fitness_center</span>
      <span className="material-symbols-rounded text-[22px]" style={{ color: "var(--muted)" }}>insights</span>
    </div>
  );
}

/**
 * The single most important commercial section on the page (D-M4;
 * design/Lifey Landing.dc.html L13/L14, and the mobile block in L15). One
 * component covers desktop + mobile + both themes — no hardcoded per-theme
 * colour set, same reasoning as BrowserWindowFrame.
 */
export async function SponsoredBand() {
  const t = await getTranslations("home.sponsored");
  const locale = await getLocale();

  return (
    <section className="py-16 md:py-24" style={{ background: "var(--surface-container)" }}>
      <div className="max-w-[1200px] mx-auto px-4 md:px-8">
        <div className="max-w-[62ch]">
          <div
            className="inline-flex items-center gap-2 h-8 px-3.5 rounded-pill text-xs font-extrabold tracking-wide"
            style={{ background: "var(--bg)", color: "var(--secondary)" }}
          >
            <span className="material-symbols-rounded text-base" style={{ fontVariationSettings: "'FILL' 1" }}>
              volunteer_activism
            </span>
            {t("eyebrow").toUpperCase()}
          </div>
          <h2 className="text-[28px] md:text-[44px] font-bold tracking-[-0.02em] leading-[1.14] md:leading-[1.12] mt-4">
            {t("title")}
          </h2>
          <p className="hidden md:block text-xl font-medium leading-[1.6] mt-4.5" style={{ color: "var(--on-surface-variant)" }}>
            {t("body")}
          </p>
        </div>

        {/* Desktop: two full phone dashboards side by side */}
        <div className="hidden md:grid grid-cols-2 gap-8 mt-11 items-start">
          <div>
            <div className="text-xs font-extrabold tracking-wide mb-3" style={{ color: "var(--muted)" }}>
              {t("freeLabel").toUpperCase()}
            </div>
            <div className="rounded-lg overflow-hidden border border-outline" style={{ background: "var(--bg)" }}>
              <PhoneDashboard t={t} pro={false} />
            </div>
          </div>
          <div>
            <div className="text-xs font-extrabold tracking-wide mb-3" style={{ color: "var(--secondary)" }}>
              {t("proLabel").toUpperCase()}
            </div>
            <div className="rounded-lg overflow-hidden border-2" style={{ background: "var(--bg)", borderColor: "var(--secondary)" }}>
              <PhoneDashboard t={t} pro={true} />
            </div>
          </div>
        </div>

        {/* Mobile: the same two states, stacked and compact */}
        <div className="md:hidden flex gap-2.5 mt-6">
          <div
            className="flex-1 rounded-md border border-outline p-2.5"
            style={{ background: "var(--bg)" }}
          >
            <div className="text-[9.5px] font-extrabold" style={{ color: "var(--muted)" }}>
              {t("freeLabel").toUpperCase()}
            </div>
            <div
              className="h-8.5 rounded-md flex items-center justify-center text-[9px] mt-6.5"
              style={{ background: "var(--surface-high)", color: "var(--on-surface-variant)" }}
            >
              {t("ad")}
            </div>
          </div>
          <div
            className="flex-1 rounded-md border p-2.5"
            style={{ background: "var(--bg)", borderColor: "var(--secondary)" }}
          >
            <div className="text-[9.5px] font-extrabold" style={{ color: "var(--secondary)" }}>
              {t("proLabelShort").toUpperCase()}
            </div>
            <div className="text-[9.5px] text-center mt-8.5" style={{ color: "var(--muted)" }}>
              {t("adNoneMobile")}
            </div>
          </div>
        </div>

        <div className="flex flex-col md:flex-row md:items-center gap-4 md:gap-4 mt-8 md:mt-10">
          <TrackedCta
            href={getPathname({ locale, href: "/pricing" })}
            page="home"
            slot="sponsored"
            audience="trainer"
            className="h-14 rounded-pill flex items-center justify-center md:justify-start px-7.5 text-base font-extrabold"
            style={{ background: "var(--primary)", color: "var(--bg)" }}
          >
            {t("cta")}
          </TrackedCta>
          <p className="text-sm font-semibold text-center md:text-left" style={{ color: "var(--muted)" }}>
            {t("footnote")}
          </p>
        </div>
      </div>
    </section>
  );
}

function PhoneDashboard({
  t,
  pro,
}: {
  t: Awaited<ReturnType<typeof getTranslations<"home.sponsored">>>;
  pro: boolean;
}) {
  return (
    <>
      <div className="px-4 pt-4">
        <div className="flex items-center justify-between">
          <div>
            <div className="text-[11px] font-bold" style={{ color: "var(--muted)" }}>{t("dateLabel").toUpperCase()}</div>
            <div className="text-[19px] font-extrabold">{t("greeting")}</div>
          </div>
          {pro ? (
            <div
              className="h-6.5 flex items-center gap-1.5 px-2.5 rounded-pill text-[10.5px] font-extrabold"
              style={{ background: "var(--secondary)", color: "var(--bg)" }}
            >
              <span className="material-symbols-rounded text-sm" style={{ fontVariationSettings: "'FILL' 1" }}>workspace_premium</span>
              PRO
            </div>
          ) : (
            <div
              className="w-8.5 h-8.5 rounded-pill flex items-center justify-center"
              style={{ background: "var(--surface-container)" }}
            >
              <span className="material-symbols-rounded text-[19px]" style={{ color: "var(--muted)" }}>notifications</span>
            </div>
          )}
        </div>
        <div className="grid grid-cols-2 gap-2 mt-3">
          <div className="rounded-md p-3" style={{ background: "var(--surface-container)" }}>
            <div className="text-[10px] font-bold" style={{ color: "var(--muted)" }}>{t("calories").toUpperCase()}</div>
            <div className="text-xl font-extrabold tabular-nums">
              1 640<span className="text-[11px]" style={{ color: "var(--muted)" }}> / 1 950</span>
            </div>
          </div>
          <div className="rounded-md p-3" style={{ background: "var(--surface-container)" }}>
            <div className="text-[10px] font-bold" style={{ color: "var(--muted)" }}>{t("steps").toUpperCase()}</div>
            <div className="text-xl font-extrabold tabular-nums">8 420</div>
          </div>
        </div>
        <div className="rounded-md p-3 mt-2" style={{ background: "var(--surface-container)" }}>
          <div className="text-[10px] font-bold" style={{ color: "var(--muted)" }}>{t("todayWorkout").toUpperCase()}</div>
          <div className="text-sm font-extrabold mt-0.5">{t("workoutName")}</div>
          <div className="text-[11px]" style={{ color: "var(--on-surface-variant)" }}>{t("workoutMeta")}</div>
        </div>
        {pro && (
          <div className="rounded-md p-3 mt-2" style={{ background: "var(--surface-container)" }}>
            <div className="text-[10px] font-bold" style={{ color: "var(--muted)" }}>{t("fullHistory").toUpperCase()}</div>
            <div className="text-sm font-extrabold mt-0.5">{t("fullHistoryValue")}</div>
          </div>
        )}
      </div>

      {pro ? (
        <div className="text-center text-[11px] py-3.5" style={{ color: "var(--muted)" }}>
          {t("adGoneCallout")}
        </div>
      ) : (
        <div className="mt-3.5 border-t border-outline px-3 pt-2 pb-2.5" style={{ background: "var(--surface-container)" }}>
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold" style={{ color: "var(--muted)" }}>{t("ad")}</span>
            <span className="material-symbols-rounded text-[22px]" style={{ color: "var(--muted)" }}>block</span>
          </div>
          <div
            className="h-12.5 rounded-md flex items-center justify-center text-[11px] mt-1.5"
            style={{ background: "var(--surface-high)", color: "var(--on-surface-variant)" }}
          >
            {t("adBanner")}
          </div>
        </div>
      )}
      <BottomNav />
    </>
  );
}
