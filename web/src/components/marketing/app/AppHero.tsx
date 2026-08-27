import Link from "next/link";
import { getTranslations } from "next-intl/server";
import { StoreBadges } from "../StoreBadges";

/**
 * docs/landing_page/65 Prompt 7 — no design frame (68 §13.2). Spec (68 §6)
 * calls for "a phone-first hero (three phones, centre one forward)"; this
 * ships one phone, not three. Building two more full mockups with no frame
 * to check them against is the same tradeoff Prompt 5's hero made (65
 * Prompt 5 landed note 2) — a second and third phone here would be
 * decoration, not information, without a design to say what they'd show.
 * `--secondary` (tan) is the only accent, per §6 — this page is the
 * individual-user "consumer story", never trainer-facing.
 */
export async function AppHero() {
  const t = await getTranslations("app.hero");

  return (
    <section className="pt-14 md:pt-20 pb-14 md:pb-20" style={{ background: "var(--bg)" }}>
      <div className="max-w-[1200px] mx-auto px-4 md:px-8 grid md:grid-cols-12 gap-10 md:gap-12 items-center">
        <div className="md:col-span-7">
          <div
            className="inline-flex items-center gap-2 h-8 px-3.5 rounded-pill text-[12.5px] font-extrabold tracking-wide"
            style={{ background: "var(--surface-container)", color: "var(--secondary)" }}
          >
            <span className="material-symbols-rounded text-base" style={{ fontVariationSettings: "'FILL' 1" }}>
              fitness_center
            </span>
            {t("eyebrow").toUpperCase()}
          </div>
          <h1 className="text-[36px] md:text-[56px] font-extrabold tracking-[-0.02em] leading-[1.08] md:leading-[1.05] mt-4 max-w-[16ch]">
            {t("title")}
          </h1>
          <p
            className="hidden md:block text-xl font-medium leading-[1.6] mt-5 max-w-[56ch]"
            style={{ color: "var(--on-surface-variant)" }}
          >
            {t("sub")}
          </p>
          <p className="md:hidden text-[17px] font-medium leading-[1.55] mt-3.5" style={{ color: "var(--on-surface-variant)" }}>
            {t("subMobile")}
          </p>

          <div className="mt-7 md:mt-8">
            <StoreBadges size="lg" page="app" />
          </div>

          <div
            className="flex items-center gap-2.5 mt-4 md:mt-5 text-sm font-semibold"
            style={{ color: "var(--muted)" }}
          >
            <span
              className="material-symbols-rounded text-lg"
              style={{ color: "var(--tertiary)", fontVariationSettings: "'FILL' 1" }}
            >
              check_circle
            </span>
            {t("reassurance")}
          </div>

          <Link href="/for-trainers" className="inline-block mt-3 text-sm font-bold" style={{ color: "var(--secondary)" }}>
            {t("trainerLink")}
          </Link>
        </div>

        <div className="md:col-span-5 flex justify-center">
          <div
            className="w-[230px] rounded-3xl overflow-hidden border-[6px]"
            style={{ background: "var(--bg)", borderColor: "var(--surface-high)", boxShadow: "0 20px 44px rgba(0,0,0,.35)" }}
          >
            <div className="h-5 flex items-center justify-center" style={{ background: "var(--surface-container)" }}>
              <div className="w-12 h-1.5 rounded-pill" style={{ background: "var(--outline)" }} />
            </div>
            <div className="p-3.5">
              <div className="text-[13px] font-bold" style={{ color: "var(--muted)" }}>{t("mockGreeting")}</div>
              <div className="grid grid-cols-2 gap-2 mt-3">
                <div className="rounded-md p-2.5" style={{ background: "var(--surface-container)" }}>
                  <div className="text-[10px] font-bold" style={{ color: "var(--muted)" }}>{t("mockKcal").toUpperCase()}</div>
                  <div className="text-lg font-extrabold tabular-nums mt-0.5">1 840</div>
                </div>
                <div className="rounded-md p-2.5" style={{ background: "var(--surface-container)" }}>
                  <div className="text-[10px] font-bold" style={{ color: "var(--muted)" }}>{t("mockSteps").toUpperCase()}</div>
                  <div className="text-lg font-extrabold tabular-nums mt-0.5">7 240</div>
                </div>
              </div>
              <div className="rounded-md p-3 mt-2.5" style={{ background: "var(--secondary)", color: "var(--bg)" }}>
                <div className="text-[10.5px] font-bold opacity-80">{t("mockWorkoutLabel").toUpperCase()}</div>
                <div className="text-[15px] font-extrabold mt-0.5">{t("mockWorkoutName")}</div>
                <div className="text-[11px] font-semibold opacity-80 mt-0.5">{t("mockWorkoutMeta")}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
