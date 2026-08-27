import { getLocale, getTranslations } from "next-intl/server";
import { getPathname } from "@/i18n/navigation";
import { TrackedCta } from "../TrackedCta";

/** design/Lifey Landing.dc.html L07 (desktop) / L09 (mobile, top half). */
export async function Fork() {
  const t = await getTranslations("home.fork");
  const locale = await getLocale();

  return (
    <section className="py-16 md:py-24" style={{ background: "var(--surface-container)" }}>
      <div className="max-w-[1200px] mx-auto px-4 md:px-8 grid md:grid-cols-2 gap-6 md:gap-8">
        <div
          className="rounded-lg border border-outline p-7 md:p-10"
          style={{ background: "var(--bg)", borderTop: "4px solid var(--primary)" }}
        >
          <div
            className="w-11 h-11 md:w-13 md:h-13 rounded-md flex items-center justify-center"
            style={{ background: "var(--primary)", color: "var(--bg)" }}
          >
            <span className="material-symbols-rounded text-[26px] md:text-[30px]" style={{ fontVariationSettings: "'FILL' 1" }}>
              groups
            </span>
          </div>
          <h2 className="text-[22px] md:text-[28px] font-bold mt-5">{t("trainerTitle")}</h2>
          <p
            className="hidden md:block text-[17px] leading-[1.6] mt-3"
            style={{ color: "var(--on-surface-variant)" }}
          >
            {t("trainerBody")}
          </p>
          <p className="md:hidden text-[15px] leading-[1.6] mt-2.5" style={{ color: "var(--on-surface-variant)" }}>
            {t("trainerBodyShort")}
          </p>
          <TrackedCta
            href={getPathname({ locale, href: "/for-trainers" })}
            page="home"
            slot="fork-trainer"
            audience="trainer"
            className="inline-flex h-13 md:h-14 items-center px-6 md:px-7 rounded-pill text-[15px] md:text-base font-extrabold mt-5 md:mt-6.5"
            style={{ background: "var(--primary)", color: "var(--bg)" }}
          >
            {t("trainerCta")}
          </TrackedCta>
        </div>

        <div
          className="rounded-lg border border-outline p-7 md:p-10"
          style={{ background: "var(--bg)", borderTop: "4px solid var(--secondary)" }}
        >
          <div
            className="w-11 h-11 md:w-13 md:h-13 rounded-md flex items-center justify-center"
            style={{ background: "var(--secondary)", color: "var(--bg)" }}
          >
            <span className="material-symbols-rounded text-[26px] md:text-[30px]" style={{ fontVariationSettings: "'FILL' 1" }}>
              fitness_center
            </span>
          </div>
          <h2 className="text-[22px] md:text-[28px] font-bold mt-5">{t("clientTitle")}</h2>
          <p
            className="hidden md:block text-[17px] leading-[1.6] mt-3"
            style={{ color: "var(--on-surface-variant)" }}
          >
            {t("clientBody")}
          </p>
          <p className="md:hidden text-[15px] leading-[1.6] mt-2.5" style={{ color: "var(--on-surface-variant)" }}>
            {t("clientBodyShort")}
          </p>
          <TrackedCta
            href={getPathname({ locale, href: "/download" })}
            page="home"
            slot="fork-client"
            audience="client"
            className="inline-flex h-13 md:h-14 items-center px-6 md:px-7 rounded-pill text-[15px] md:text-base font-extrabold mt-5 md:mt-6.5"
            style={{ background: "var(--secondary)", color: "var(--bg)" }}
          >
            {t("clientCta")}
          </TrackedCta>
        </div>
      </div>
    </section>
  );
}
