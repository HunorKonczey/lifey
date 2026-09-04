import { getTranslations } from "next-intl/server";

/** design/Lifey Landing.dc.html L12 — desktop only, used by ValueSection. Not
 * a browser-window mockup (chat has its own app-like chrome in the design). */
export async function ChatMock() {
  const t = await getTranslations("home.chat");

  const reports = [
    { name: "Szabó Anna", ratio: "4/4", pct: 100, ok: true },
    { name: "Tóth Márk", ratio: "2/4", pct: 50, ok: false },
    { name: "Nagy Réka", ratio: "3/3", pct: 100, ok: true },
    { name: "Horváth Lilla", ratio: "3/3", pct: 100, ok: true },
  ];

  return (
    <div className="flex gap-4">
      <div
        className="flex-1 rounded-lg overflow-hidden border border-outline"
        style={{ background: "var(--surface)", boxShadow: "0 24px 60px rgba(0,0,0,.25)" }}
      >
        <div className="flex items-center gap-2.5 p-3.5 border-b border-outline">
          <span
            className="w-8.5 h-8.5 rounded-pill flex items-center justify-center text-xs font-extrabold"
            style={{ background: "var(--secondary)", color: "var(--bg)" }}
          >
            SZ
          </span>
          <div>
            <div className="text-[13.5px] font-extrabold">Szabó Anna</div>
            <div className="text-[10.5px]" style={{ color: "var(--tertiary)" }}>{t("mockOnline")}</div>
          </div>
        </div>
        <div className="p-3.5 flex flex-col gap-2.5 h-[340px]">
          <div
            className="rounded-lg rounded-tl-sm px-3 py-2.5 max-w-[88%]"
            style={{ background: "var(--surface-container)" }}
          >
            <div className="text-xs leading-[1.5]">{t("mockClientMsg")}</div>
            <div className="text-[9.5px] mt-1" style={{ color: "var(--muted)" }}>14:02</div>
          </div>
          <div className="rounded-md border border-outline px-2.5 py-2 max-w-[88%]">
            <div className="text-[9.5px] font-extrabold tracking-wide" style={{ color: "var(--muted)" }}>
              {t("mockWorkoutContext").toUpperCase()}
            </div>
            <div className="text-[11.5px] font-bold mt-0.5">{t("mockWorkoutContextValue")}</div>
            <div className="text-[10.5px] tabular-nums" style={{ color: "var(--on-surface-variant)" }}>
              {t("mockWorkoutContextSet")}
            </div>
          </div>
          <div
            className="self-end rounded-lg rounded-tr-sm px-3 py-2.5 max-w-[88%]"
            style={{ background: "var(--primary)", color: "var(--bg)" }}
          >
            <div className="text-xs leading-[1.5] font-semibold">{t("mockTrainerMsg")}</div>
            {/* No opacity here (unlike a plain text-muted timestamp elsewhere) —
                Lighthouse measured 70% opacity on this specific small (9.5px)
                text as only 4.19:1 against the primary background, just under
                the 4.5:1 AA minimum; full opacity clears ~7.5:1. */}
            <div className="text-[9.5px] mt-1">14:09</div>
          </div>
          <div
            className="mt-auto h-10 rounded-pill flex items-center px-3.5 text-xs"
            style={{ background: "var(--surface-container)", color: "var(--muted)" }}
          >
            {t("mockInputPlaceholder")}
          </div>
        </div>
      </div>

      <div
        className="w-[250px] rounded-lg border border-outline p-4"
        style={{ background: "var(--surface)", boxShadow: "0 24px 60px rgba(0,0,0,.25)" }}
      >
        <div className="text-[13px] font-extrabold">{t("mockReportTitle")}</div>
        <div className="text-[11px] tabular-nums" style={{ color: "var(--muted)" }}>{t("mockReportPeriod")}</div>
        <div className="flex flex-col gap-2 mt-3.5">
          {reports.map((r) => (
            <div key={r.name} className="rounded-md p-2.5" style={{ background: "var(--surface-container)" }}>
              <div className="flex justify-between">
                <span className="text-[11.5px] font-bold">{r.name}</span>
                <span
                  className="text-[11px] font-extrabold tabular-nums"
                  style={{ color: r.ok ? "var(--tertiary)" : "var(--secondary)" }}
                >
                  {r.ratio}
                </span>
              </div>
              <div className="h-1 rounded-pill mt-1.5" style={{ background: "var(--outline)" }}>
                <div
                  className="h-1 rounded-pill"
                  style={{ width: `${r.pct}%`, background: r.ok ? "var(--tertiary)" : "var(--secondary)" }}
                />
              </div>
            </div>
          ))}
        </div>
        <div
          className="rounded-md p-2.5 mt-3 text-[11px] leading-[1.5]"
          style={{ background: "var(--surface-high)", color: "var(--on-surface-variant)" }}
        >
          {t("mockReportNote")}
        </div>
      </div>
    </div>
  );
}
