import { getTranslations } from "next-intl/server";
import { ValueSection } from "./ValueSection";
import { ChatMock } from "./ChatMock";

/** design/Lifey Landing.dc.html L12 (desktop) + L15 third block (mobile). */
export async function ChatSection() {
  const t = await getTranslations("home.chat");

  const bullets = [t("bullet1"), t("bullet2"), t("bullet3")];

  return (
    <>
      <ValueSection
        eyebrow={t("eyebrow")}
        title={t("title")}
        body={t("body")}
        bullets={bullets}
        visual={<ChatMock />}
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
        <div
          className="rounded-lg border border-outline p-3 mt-4.5 flex flex-col gap-2"
          style={{ background: "var(--surface)" }}
        >
          <div
            className="rounded-lg rounded-tl-sm px-2.5 py-2 text-[11.5px] leading-[1.5]"
            style={{ background: "var(--surface-container)" }}
          >
            {t("mockClientMsgShort")}
          </div>
          <div
            className="self-end rounded-lg rounded-tr-sm px-2.5 py-2 text-[11.5px] font-semibold leading-[1.5]"
            style={{ background: "var(--primary)", color: "#161611" }}
          >
            {t("mockTrainerMsgShort")}
          </div>
        </div>
      </section>
    </>
  );
}
