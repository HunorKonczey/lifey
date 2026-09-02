import { getTranslations } from "next-intl/server";
import { BrowserWindowFrame } from "./BrowserWindowFrame";

/** design/Lifey Landing.dc.html L11 — desktop only, used by ValueSection. */
export async function ProgramMock() {
  const t = await getTranslations("home.program");
  const demo = await getTranslations("home.demo");

  const weeks = [
    { label: t("mockWeek3"), active: true },
    { label: t("mockWeek4"), active: false },
    { label: t("mockWeek5"), active: false },
  ];
  const exercises = [
    { name: demo("squat"), sets: "5×5 · 82,5 kg" },
    { name: demo("benchPress"), sets: "5×5 · 65 kg" },
    { name: demo("row"), sets: "5×5 · 60 kg" },
    { name: demo("plank"), sets: "3×60 s" },
  ];
  const otherDays = [t("mockWednesday"), t("mockFriday")];

  return (
    <BrowserWindowFrame url="lifey.hu/admin/programs/ero-5x5">
      <div className="flex">
        <div className="flex-1 p-4.5">
          <div className="flex items-center justify-between">
            <div>
              <div className="text-[17px] font-extrabold">{t("mockProgramName")}</div>
              <div className="text-[11.5px]" style={{ color: "var(--muted)" }}>{t("mockProgramMeta")}</div>
            </div>
            <div
              className="h-7.5 flex items-center px-3.5 rounded-pill text-[11.5px] font-extrabold"
              style={{ background: "var(--primary)", color: "var(--bg)" }}
            >
              {t("mockAssign")}
            </div>
          </div>

          <div className="flex gap-1.5 mt-3.5">
            {weeks.map((w) => (
              <div
                key={w.label}
                className="h-7 flex items-center px-3 rounded-pill text-[11px]"
                style={
                  w.active
                    ? { background: "var(--primary)", color: "var(--bg)", fontWeight: 800 }
                    : { background: "var(--surface-high)", color: "var(--on-surface-variant)", fontWeight: 700 }
                }
              >
                {w.label}
              </div>
            ))}
            <div
              className="h-7 flex items-center px-3 rounded-pill text-[11px] font-bold border border-dashed border-outline"
              style={{ color: "var(--muted)" }}
            >
              {t("mockAddWeek")}
            </div>
          </div>

          <div className="flex flex-col gap-2 mt-3.5">
            <div className="rounded-md p-3" style={{ background: "var(--surface-container)" }}>
              <div className="flex items-center gap-2">
                <span className="material-symbols-rounded text-base" style={{ color: "var(--muted)" }}>drag_indicator</span>
                <div className="text-[12.5px] font-extrabold flex-1">{t("mockMonday")}</div>
                <span className="text-[11px]" style={{ color: "var(--muted)" }}>{t("mockExerciseCount")}</span>
              </div>
              <div className="flex flex-col gap-1.5 mt-2.5 pl-6">
                {exercises.map((ex) => (
                  <div key={ex.name} className="flex items-center gap-2.5">
                    <span className="text-[11.5px] font-bold flex-1">{ex.name}</span>
                    <span className="text-[11px] tabular-nums" style={{ color: "var(--on-surface-variant)" }}>{ex.sets}</span>
                  </div>
                ))}
              </div>
            </div>
            {otherDays.map((day) => (
              <div key={day} className="rounded-md p-3" style={{ background: "var(--surface-container)" }}>
                <div className="flex items-center gap-2">
                  <span className="material-symbols-rounded text-base" style={{ color: "var(--muted)" }}>drag_indicator</span>
                  <div className="text-[12.5px] font-extrabold flex-1">{day}</div>
                  <span className="text-[11px]" style={{ color: "var(--muted)" }}>{t("mockExerciseCount")}</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="w-[220px] border-l border-outline p-4.5" style={{ background: "var(--bg)" }}>
          <div className="text-[13px] font-extrabold">{t("mockScheduling")}</div>
          <div className="text-[11.5px] mt-0.5" style={{ color: "var(--muted)" }}>{t("mockSchedulingFor")}</div>
          <div className="flex flex-col gap-2 mt-3.5">
            <div className="rounded-md p-2.5" style={{ background: "var(--surface-container)" }}>
              <div className="text-[10.5px] font-bold" style={{ color: "var(--muted)" }}>{t("mockDate").toUpperCase()}</div>
              <div className="text-[13px] font-extrabold tabular-nums">2026. aug. 26.</div>
            </div>
            <div className="rounded-md p-2.5" style={{ background: "var(--surface-container)" }}>
              <div className="text-[10.5px] font-bold" style={{ color: "var(--muted)" }}>{t("mockTime").toUpperCase()}</div>
              <div className="text-[13px] font-extrabold tabular-nums">17:00 — 18:00</div>
            </div>
            <div className="rounded-md p-2.5" style={{ background: "var(--surface-container)" }}>
              <div className="text-[10.5px] font-bold" style={{ color: "var(--muted)" }}>{t("mockLocation").toUpperCase()}</div>
              <div className="text-[13px] font-extrabold">{t("mockLocationValue")}</div>
            </div>
          </div>
          <div className="rounded-md p-2.5 mt-3" style={{ background: "var(--surface-high)" }}>
            <div className="text-[11.5px] leading-[1.5]" style={{ color: "var(--on-surface-variant)" }}>{t("mockRecurrence")}</div>
          </div>
          <div
            className="h-11 rounded-pill flex items-center justify-center text-[13px] font-extrabold mt-3"
            style={{ background: "var(--primary)", color: "var(--bg)" }}
          >
            {t("mockSave")}
          </div>
        </div>
      </div>
    </BrowserWindowFrame>
  );
}
