import { getTranslations } from "next-intl/server";
import { ValueSection } from "./ValueSection";
import { ClientsMock } from "./ClientsMock";

/**
 * design/Lifey Landing.dc.html L10 (desktop) + L15 first block (mobile —
 * copy always before the (simplified) visual, per 68 §4.4).
 */
export async function ClientsSection() {
  const t = await getTranslations("home.clients");

  const bullets = [t("bullet1"), t("bullet2"), t("bullet3")];

  return (
    <>
      <ValueSection
        eyebrow={t("eyebrow")}
        title={t("title")}
        body={t("body")}
        bullets={bullets}
        visual={<ClientsMock />}
        imageSide="right"
        background="bg"
      />

      <section className="md:hidden py-9 px-4" style={{ background: "var(--bg)" }}>
        <div className="text-[11px] font-extrabold tracking-wide" style={{ color: "var(--primary)" }}>
          {t("eyebrow").toUpperCase()}
        </div>
        <h2 className="text-[28px] font-bold tracking-[-0.02em] leading-[1.14] mt-2.5">{t("titleMobile")}</h2>
        <p className="text-[17px] leading-[1.55] mt-3" style={{ color: "var(--on-surface-variant)" }}>
          {t("bodyMobile")}
        </p>
        <div className="rounded-lg border border-outline p-3 mt-4.5" style={{ background: "var(--surface)" }}>
          <div className="text-xs font-extrabold mb-2">
            {t("mockClientsHeading")} <span style={{ color: "var(--muted)" }}>12</span>
          </div>
          <div className="flex flex-col gap-1.5">
            {[
              { name: "Szabó Anna", ratio: "4/4", bg: "var(--secondary)", ok: true },
              { name: "Tóth Márk", ratio: "2/4", bg: "var(--tertiary)", ok: false },
            ].map((row) => (
              <div
                key={row.name}
                className="flex items-center gap-2 rounded-md p-2"
                style={{ background: "var(--surface-container)" }}
              >
                <span
                  className="w-6 h-6 rounded-pill flex items-center justify-center text-[9.5px] font-extrabold"
                  style={{ background: row.bg, color: "#161611" }}
                >
                  {row.name.split(" ").map((p) => p[0]).join("")}
                </span>
                <span className="text-[11.5px] font-bold flex-1">{row.name}</span>
                <span
                  className="text-[10px] font-extrabold"
                  style={{ color: row.ok ? "var(--tertiary)" : "var(--secondary)" }}
                >
                  {row.ratio}
                </span>
              </div>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
