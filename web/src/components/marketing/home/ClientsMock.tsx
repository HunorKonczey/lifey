import { getTranslations } from "next-intl/server";
import { BrowserWindowFrame } from "./BrowserWindowFrame";

/** design/Lifey Landing.dc.html L10 — desktop only, used by ValueSection. */
export async function ClientsMock() {
  const t = await getTranslations("home.clients");
  const demo = await getTranslations("home.demo");

  const rows = [
    { name: "Szabó Anna", meta: demo("strength"), bg: "var(--secondary)", active: true },
    { name: "Tóth Márk", meta: demo("fatLoss"), bg: "var(--tertiary)", active: false },
    { name: "Nagy Réka", meta: demo("hypertrophy"), bg: "#8AA0B4", active: false },
    { name: "Kiss Dávid", meta: t("mockInvited"), bg: "#B08AC8", active: false },
    { name: "Horváth Lilla", meta: demo("cardio"), bg: "#E0915A", active: false },
  ];

  const tabs = [t("mockOverview"), t("mockWorkouts"), t("mockNutrition"), t("mockWeight"), t("mockNotes")];

  return (
    <BrowserWindowFrame url="lifey.hu/admin/clients/szabo-anna">
      <div className="flex">
        <div className="w-[220px] border-r border-outline p-4">
          <div className="text-sm font-extrabold mb-3">
            {t("mockClientsHeading")} <span className="font-semibold" style={{ color: "var(--muted)" }}>12</span>
          </div>
          <div
            className="h-8.5 rounded-pill flex items-center gap-2 px-3 text-xs mb-3"
            style={{ background: "var(--surface-container)", color: "var(--muted)" }}
          >
            <span className="material-symbols-rounded text-base">search</span>
            {t("mockSearch")}
          </div>
          <div className="flex flex-col gap-1.5">
            {rows.map((row) => (
              <div
                key={row.name}
                className="flex items-center gap-2.5 rounded-md px-2.5 py-2"
                style={row.active ? { background: "var(--primary)", color: "#161611" } : {}}
              >
                <span
                  className="w-7 h-7 rounded-pill flex items-center justify-center text-[10.5px] font-extrabold"
                  style={{ background: row.active ? "#161611" : row.bg, color: row.active ? "var(--secondary)" : "#161611" }}
                >
                  {row.name.split(" ").map((p) => p[0]).join("")}
                </span>
                <div className="flex-1">
                  <div className="text-xs font-extrabold">{row.name}</div>
                  <div
                    className="text-[10px] font-semibold"
                    style={{ opacity: row.active ? 0.75 : 1, color: row.active ? undefined : "var(--muted)" }}
                  >
                    {row.meta}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="flex-1 p-4.5">
          <div className="flex items-center gap-3">
            <span
              className="w-11 h-11 rounded-pill flex items-center justify-center text-[15px] font-extrabold"
              style={{ background: "var(--secondary)", color: "#161611" }}
            >
              SZ
            </span>
            <div>
              <div className="text-lg font-extrabold">Szabó Anna</div>
              <div className="text-xs" style={{ color: "var(--muted)" }}>
                {demo("strength")} · {t("mockProgramLength")}
              </div>
            </div>
            <div className="ml-auto flex gap-2">
              <div className="h-8 flex items-center px-3.5 rounded-pill border border-outline text-xs font-bold">
                {t("mockMessage")}
              </div>
              <div
                className="h-8 flex items-center px-3.5 rounded-pill text-xs font-extrabold"
                style={{ background: "var(--primary)", color: "#161611" }}
              >
                {t("mockProgram")}
              </div>
            </div>
          </div>

          <div className="flex gap-4.5 mt-4 border-b border-outline pb-2 text-xs font-bold" style={{ color: "var(--muted)" }}>
            {tabs.map((tab, i) => (
              <span
                key={tab}
                className={i === 0 ? "pb-2" : ""}
                style={i === 0 ? { color: "var(--on-surface)", borderBottom: "2px solid var(--primary)" } : {}}
              >
                {tab}
              </span>
            ))}
          </div>

          <div className="grid grid-cols-3 gap-2.5 mt-3.5">
            <div className="rounded-md p-3" style={{ background: "var(--surface-container)" }}>
              <div className="text-[10.5px] font-bold" style={{ color: "var(--muted)" }}>{t("mockWeeklyWorkouts").toUpperCase()}</div>
              <div className="text-2xl font-extrabold tabular-nums mt-1">4/4</div>
            </div>
            <div className="rounded-md p-3" style={{ background: "var(--surface-container)" }}>
              <div className="text-[10.5px] font-bold" style={{ color: "var(--muted)" }}>{t("mockWeightLabel").toUpperCase()}</div>
              <div className="text-2xl font-extrabold tabular-nums mt-1">
                64,2<span className="text-xs" style={{ color: "var(--muted)" }}> kg</span>
              </div>
            </div>
            <div className="rounded-md p-3" style={{ background: "var(--surface-container)" }}>
              <div className="text-[10.5px] font-bold" style={{ color: "var(--muted)" }}>{t("mockAvgKcal").toUpperCase()}</div>
              <div className="text-2xl font-extrabold tabular-nums mt-1">1 940</div>
            </div>
          </div>

          <div className="rounded-md p-3.5 mt-2.5" style={{ background: "var(--surface-container)" }}>
            <div className="text-xs font-extrabold mb-2.5">{t("mockLastWorkouts")}</div>
            <div className="flex flex-col gap-2">
              {[
                { icon: "fitness_center", name: "Erő 5×5 — A", meta: "aug. 24. · 52 perc", color: "var(--primary)" },
                { icon: "fitness_center", name: "Erő 5×5 — B", meta: "aug. 22. · 48 perc", color: "var(--primary)" },
                { icon: "directions_run", name: "Futás · 6,2 km", meta: "aug. 21. · 34 perc", color: "var(--metric-water)" },
              ].map((w) => (
                <div key={w.name} className="flex items-center gap-2.5">
                  <span className="material-symbols-rounded text-base" style={{ color: w.color, fontVariationSettings: "'FILL' 1" }}>
                    {w.icon}
                  </span>
                  <span className="text-[11.5px] font-bold flex-1">{w.name}</span>
                  <span className="text-[11px] tabular-nums" style={{ color: "var(--muted)" }}>{w.meta}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </BrowserWindowFrame>
  );
}
