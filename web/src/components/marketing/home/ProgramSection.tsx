import { getTranslations } from "next-intl/server";
import { ValueSection } from "./ValueSection";
import { ProgramMock } from "./ProgramMock";

/** design/Lifey Landing.dc.html L11 (desktop) + L15 second block (mobile). */
export async function ProgramSection() {
  const t = await getTranslations("home.program");

  const bullets = [t("bullet1"), t("bullet2"), t("bullet3")];

  return (
    <>
      <ValueSection
        eyebrow={t("eyebrow")}
        title={t("title")}
        body={t("body")}
        bullets={bullets}
        visual={<ProgramMock />}
        imageSide="left"
        background="container"
      />

      <section className="md:hidden py-9 px-4" style={{ background: "var(--surface-container)" }}>
        <div className="text-[11px] font-extrabold tracking-wide" style={{ color: "var(--primary)" }}>
          {t("eyebrow").toUpperCase()}
        </div>
        <h2 className="text-[28px] font-bold tracking-[-0.02em] leading-[1.14] mt-2.5">{t("titleMobile")}</h2>
        <p className="text-[17px] leading-[1.55] mt-3" style={{ color: "var(--on-surface-variant)" }}>
          {t("bodyMobile")}
        </p>
        <div className="rounded-lg border border-outline p-3 mt-4.5" style={{ background: "var(--surface)" }}>
          <div className="text-xs font-extrabold">{t("mockProgramName")} · {t("mockWeek3")}</div>
          <div className="flex flex-col gap-1.5 mt-2">
            <div
              className="rounded-md p-2 text-[11px] font-bold"
              style={{ background: "var(--surface-container)" }}
            >
              {t("mockMonday")} <span className="font-semibold" style={{ color: "var(--muted)" }}>· {t("mockExerciseCount")}</span>
            </div>
            <div
              className="rounded-md p-2 text-[11px] font-bold"
              style={{ background: "var(--surface-container)" }}
            >
              {t("mockWednesday")} <span className="font-semibold" style={{ color: "var(--muted)" }}>· {t("mockExerciseCount")}</span>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
