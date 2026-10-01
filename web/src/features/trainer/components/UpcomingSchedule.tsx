"use client";

import Link from "next/link";
import { useTranslations } from "next-intl";
import { Card } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import type { TrainerCalendarSessionResponse } from "../types";

const MAX_ROWS = 3;

/** "Következő · Ütemterv" (W7-B): the client's next scheduled workouts — "H 29 · Láb + core · 18:00 · program 3. hét". */
export function UpcomingSchedule({ sessions, clientId }: { sessions: TrainerCalendarSessionResponse[]; clientId: number }) {
  const t = useTranslations("admin.clientDetail.overview");
  const fmt = useFormat();
  return (
    <Card variant="card" className="flex flex-col gap-3">
      <div className="flex items-center justify-between gap-3">
        <h3 style={{ fontSize: 18, fontWeight: 800 }}>{t("upcomingTitle")}</h3>
        <Link href={`/admin/clients/${clientId}?tab=schedule`} className="type-body-s" style={{ color: "var(--primary)", fontWeight: 700 }}>
          {t("openSchedule")}
        </Link>
      </div>
      {sessions.length === 0 ? (
        <p className="type-body-s" style={{ color: "var(--text-2)" }}>{t("nothingScheduled")}</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {sessions.slice(0, MAX_ROWS).map((s) => {
            const d = new Date(s.scheduledFor + "T00:00:00");
            return (
              <li key={s.sessionId} className="flex items-center gap-3 p-3" style={{ borderRadius: "var(--r-control)", background: "var(--nested)" }}>
                <span className="num shrink-0" style={{ fontWeight: 800, width: 52 }}>
                  {fmt.weekdayShort(d)} {d.getDate()}
                </span>
                <span className="flex flex-col min-w-0">
                  <span className="truncate" style={{ fontWeight: 700 }}>{s.templateName ?? t("freeWorkout")}</span>
                  <span className="type-body-s truncate" style={{ color: "var(--text-2)" }}>
                    {[s.scheduledTime ? fmt.time(new Date(`${s.scheduledFor}T${s.scheduledTime}`)) : null, s.programName].filter(Boolean).join(" · ")}
                  </span>
                </span>
              </li>
            );
          })}
        </ul>
      )}
    </Card>
  );
}
