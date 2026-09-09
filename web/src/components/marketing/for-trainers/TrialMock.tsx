import { getTranslations } from "next-intl/server";

/** A trial-status card — the kind of chip the app itself would show a trainer mid-trial. */
export async function TrialMock() {
  const t = await getTranslations("forTrainers.block6");

  return (
    <div
      className="rounded-lg border border-outline p-5 md:p-6"
      style={{ background: "var(--surface)", boxShadow: "0 24px 60px rgba(0,0,0,.25)" }}
    >
      <div className="flex items-center justify-between">
        <div className="text-sm font-extrabold">{t("mockTitle")}</div>
        <span className="text-lg font-extrabold tabular-nums" style={{ color: "var(--tertiary)" }}>
          14 / 14
        </span>
      </div>
      <div className="h-2 rounded-pill mt-2.5" style={{ background: "var(--outline)" }}>
        <div className="h-2 rounded-pill w-full" style={{ background: "var(--tertiary)" }} />
      </div>
      <div className="text-[11.5px] mt-1.5" style={{ color: "var(--muted)" }}>{t("mockDaysLeft")}</div>

      <div className="flex flex-col gap-2 mt-4">
        <div className="flex items-center gap-2.5 rounded-md px-3 py-2.5" style={{ background: "var(--surface-container)" }}>
          <span className="material-symbols-rounded text-lg" style={{ color: "var(--primary)" }}>credit_card_off</span>
          <span className="text-[12.5px] font-bold">{t("mockNoCard")}</span>
        </div>
        <div className="flex items-center gap-2.5 rounded-md px-3 py-2.5" style={{ background: "var(--surface-container)" }}>
          <span className="material-symbols-rounded text-lg" style={{ color: "var(--primary)" }}>how_to_reg</span>
          <span className="text-[12.5px] font-bold">{t("mockYouChoose")}</span>
        </div>
      </div>
    </div>
  );
}
