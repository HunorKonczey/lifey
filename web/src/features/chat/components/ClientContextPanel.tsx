"use client";

import Link from "next/link";
import { useMemo } from "react";
import { useTranslations } from "next-intl";
import { useQuery } from "@tanstack/react-query";
import { addDays, format, startOfWeek } from "date-fns";
import { Button, Card, Icon } from "@/components/ds";
import { queryKeys } from "@/lib/api/queryKeys";
import { useFormat } from "@/lib/format/useFormat";
import { trainerApi } from "@/features/trainer/api";
import { weekSummary, weightChange } from "@/features/trainer/clientSignals";
import { WeightDelta } from "@/features/trainer/components/WeightDelta";

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-0.5">
      <dt className="type-body-s" style={{ color: "var(--text-2)" }}>{label}</dt>
      <dd style={{ fontSize: 20, fontWeight: 800, lineHeight: 1.2 }}>{children}</dd>
    </div>
  );
}

/**
 * "MÁTÉ ADATAI" (W8-D): the client's current numbers next to the conversation, so a trainer answers with the facts in
 * view — the 7-day calorie average, this week's workouts, the latest weight and its 30-day change, the next two workouts —
 * and "Kliens megnyitása". Everything comes from the same client summary and calendar feed the clients page uses
 * (W7.1 signals), so the numbers match the client's card. A missing figure shows "—", never 0.
 */
export function ClientContextPanel({ clientUserId, displayName, bare = false }: { clientUserId: number; displayName: string; bare?: boolean }) {
  const t = useTranslations("chat");
  const fmt = useFormat();
  const today = useMemo(() => new Date(), []);
  const weekStart = format(startOfWeek(today, { weekStartsOn: 1 }), "yyyy-MM-dd");
  const todayIso = format(today, "yyyy-MM-dd");
  const rangeEnd = format(addDays(new Date(weekStart + "T00:00:00"), 20), "yyyy-MM-dd");

  const clientsQ = useQuery({ queryKey: queryKeys.trainerClients.all(), queryFn: trainerApi.clients });
  const calendarQ = useQuery({ queryKey: queryKeys.trainerCalendar.range(weekStart, rangeEnd), queryFn: () => trainerApi.calendarSessions(weekStart, rangeEnd) });

  const client = clientsQ.data?.find((c) => c.clientId === clientUserId);
  const week = useMemo(() => weekSummary(calendarQ.data ?? [], clientUserId, weekStart, todayIso), [calendarQ.data, clientUserId, weekStart, todayIso]);
  const upcoming = useMemo(
    () => (calendarQ.data ?? []).filter((s) => s.clientId === clientUserId && s.status === "UPCOMING" && s.scheduledFor >= todayIso).sort((a, b) => a.scheduledFor.localeCompare(b.scheduledFor) || (a.scheduledTime ?? "").localeCompare(b.scheduledTime ?? "")).slice(0, 2),
    [calendarQ.data, clientUserId, todayIso],
  );
  const weight = client ? weightChange(client.weightTrend, today) : null;
  const first = displayName.trim().split(/\s+/)[0] ?? displayName;

  const dash = <span style={{ color: "var(--text-3)" }}>—</span>;

  const body = (
    <div className="flex flex-col gap-5" data-testid="client-context">
      {!bare && (
        <h2 className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 800, letterSpacing: "0.06em", textTransform: "uppercase" }}>
          {t("contextTitle", { name: first })}
        </h2>
      )}
      <dl className="flex flex-col gap-4">
        <Row label={t("contextCalories")}>
          {client?.avgCalories7d != null ? <><span className="num">{fmt.number(client.avgCalories7d, 0)}</span> <span className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 600 }}>kcal</span></> : dash}
        </Row>
        <Row label={t("contextWorkouts")}>
          {week.scheduled > 0 ? <span className="num">{week.done} / {week.scheduled}</span> : dash}
        </Row>
        <Row label={t("contextWeight")}>
          {weight ? (
            <span className="inline-flex flex-wrap items-center gap-2">
              <span><span className="num">{fmt.number(weight.latestKg, 1)}</span> <span className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 600 }}>kg</span></span>
              {weight.deltaKg != null && <WeightDelta kg={weight.deltaKg} />}
            </span>
          ) : dash}
        </Row>
      </dl>
      <div className="flex flex-col gap-2">
        <h3 className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 700 }}>{t("contextNext")}</h3>
        {upcoming.length === 0 ? (
          <p className="type-body-s" style={{ color: "var(--text-3)" }}>{t("contextNothingNext")}</p>
        ) : (
          <ul className="flex flex-col gap-2">
            {upcoming.map((s) => {
              const d = new Date(s.scheduledFor + "T00:00:00");
              return (
                <li key={s.sessionId} className="flex items-center gap-2.5 p-2.5" style={{ borderRadius: "var(--r-control)", background: "var(--nested)" }}>
                  <Icon name="event" size={18} color="var(--text-2)" />
                  <span className="flex flex-col min-w-0">
                    <span className="truncate" style={{ fontWeight: 700 }}>{s.templateName ?? t("contextWorkout")}</span>
                    <span className="type-body-s" style={{ color: "var(--text-2)" }}>
                      {fmt.weekdayShort(d)}, {fmt.shortDate(d)}{s.scheduledTime ? ` · ${fmt.time(new Date(`${s.scheduledFor}T${s.scheduledTime}`))}` : ""}
                    </span>
                  </span>
                </li>
              );
            })}
          </ul>
        )}
      </div>
      <Link href={`/admin/clients/${clientUserId}`}>
        <Button variant="secondary" fullWidth>
          <Icon name="open_in_new" size={18} />
          {t("openClient")}
        </Button>
      </Link>
    </div>
  );

  return bare ? body : <Card variant="card" className="overflow-y-auto min-h-0">{body}</Card>;
}
