"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Button, ConfirmModal, Icon, IconButton, Popover } from "@/components/ds";
import { useFormat } from "@/lib/format/useFormat";
import { useToast } from "@/lib/hooks/useToast";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { STATUS_STYLE } from "../scheduleStatus";
import { ClientAvatar, nameFor } from "./ClientAvatar";
import { RecurrenceLabel } from "./RecurrenceLabel";
import type { TrainerCalendarSessionResponse } from "../types";

interface CalendarSessionPeekProps {
  session: TrainerCalendarSessionResponse;
  anchorEl: HTMLElement;
  /** The client's real name when the caller has it; otherwise one derived from the e-mail. */
  clientName?: string;
  onClose: () => void;
}

/**
 * The popover of a calendar event (W8.2), on the DS `Popover`: anchored to the card, closes on Esc and an outside click
 * and returns focus to it. Client, workout, when (time without seconds) with the status in words, the series it belongs
 * to or the program chip, then the actions — the client's schedule, the finished session, or cancelling an upcoming
 * occurrence behind a confirmation. Render with `key={session.sessionId}` so another event remounts it fresh.
 */
export function CalendarSessionPeek({ session, anchorEl, clientName, onClose }: CalendarSessionPeekProps) {
  const t = useTranslations("admin.calendar");
  const tSchedule = useTranslations("admin.schedule");
  const fmt = useFormat();
  const router = useRouter();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const anchorRef = useRef<HTMLElement | null>(anchorEl);
  const [confirming, setConfirming] = useState(false);

  const schedulesQ = useQuery({
    queryKey: queryKeys.trainerSchedules.forClient(session.clientId),
    queryFn: () => trainerApi.schedulesForClient(session.clientId),
  });
  const schedule = schedulesQ.data?.find((s) => s.id === session.scheduleId);

  const cancelMutation = useMutation({
    mutationFn: () => trainerApi.cancelOccurrence(session.sessionId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["trainer-calendar"] });
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerSchedules.forClient(session.clientId) });
      show(tSchedule("occurrenceCancelled"), "success");
      onClose();
    },
    onError: () => show(tSchedule("occurrenceCancelFailed"), "error"),
  });

  const style = STATUS_STYLE[session.status];
  const name = clientName ?? nameFor(session.clientEmail);
  const day = new Date(`${session.scheduledFor}T00:00:00`);
  const scheduleHref = `/admin/clients/${session.clientId}?tab=schedule`;
  const sessionHref = `/admin/clients/${session.clientId}?tab=workouts&focusSessionId=${session.sessionId}`;

  return (
    <>
      <Popover open={!confirming} onClose={onClose} anchorRef={anchorRef} width={340}>
        <div role="dialog" aria-label={t("peekTitle")} className="flex flex-col gap-4 p-4">
          <div className="flex items-center gap-3">
            <ClientAvatar clientId={session.clientId} email={session.clientEmail} size={42} />
            <div className="flex-1 min-w-0">
              <p className="truncate" style={{ fontSize: 15, fontWeight: 800 }}>{name}</p>
              <p className="type-body-s truncate" style={{ color: "var(--text-2)" }}>{session.clientEmail}</p>
            </div>
            <IconButton icon="close" label={t("close")} onClick={onClose} />
          </div>

          <div className="flex flex-col gap-2.5 pt-3" style={{ borderTop: "1px solid var(--hairline)" }}>
            <div className="flex items-center gap-2.5">
              <Icon name="fitness_center" size={18} fill={1} color="var(--role)" />
              <span style={{ fontWeight: 700 }}>{session.templateName ?? tSchedule("unnamedTemplate")}</span>
            </div>
            <div className="flex flex-wrap items-center gap-x-2.5 gap-y-1.5">
              <Icon name="event" size={18} color="var(--text-2)" />
              <span className="type-body-s" style={{ fontWeight: 600 }}>
                {fmt.weekdayShort(day)}, {fmt.shortDate(day)}
                {session.scheduledTime && <> · <span className="num" style={{ fontWeight: 800 }}>{fmt.time(new Date(`${session.scheduledFor}T${session.scheduledTime}`))}</span></>}
              </span>
              <span
                className="inline-flex items-center gap-1.5 px-2.5 type-body-s"
                style={{ height: 26, borderRadius: 999, background: style.bg, color: style.color, fontWeight: 700, boxShadow: style.bg === "transparent" ? "inset 0 0 0 1px var(--hairline)" : undefined }}
              >
                <Icon name={style.icon} size={14} fill={style.fill ? 1 : 0} />
                {tSchedule(`status.${session.status}`)}
              </span>
            </div>
            {schedule && (
              <div className="flex items-start gap-2.5">
                <Icon name="event_repeat" size={18} color="var(--text-2)" />
                <span className="type-body-s" style={{ color: "var(--text-2)" }}>
                  <RecurrenceLabel recurrence={schedule.recurrence} daysOfWeek={schedule.daysOfWeek} timeOfDay={schedule.timeOfDay} startDate={schedule.startDate} endDate={schedule.endDate} />
                </span>
              </div>
            )}
            {session.programAssignmentId != null && session.programName && (
              <div className="flex items-center gap-2.5">
                <Icon name="event_repeat" size={18} color="var(--text-2)" />
                <span className="inline-flex items-center px-2.5 type-body-s" style={{ height: 26, borderRadius: 999, background: "color-mix(in srgb, var(--role) 16%, transparent)", fontWeight: 700 }}>
                  {session.programName}
                </span>
              </div>
            )}
          </div>

          <div className="flex flex-col gap-2 pt-3" style={{ borderTop: "1px solid var(--hairline)" }}>
            <Button variant="secondary" fullWidth onClick={() => router.push(scheduleHref)}>
              <Icon name="open_in_new" size={18} />
              {t("clientSchedule")}
            </Button>
            {session.status === "DONE" && (
              <Button variant="tonal" fullWidth onClick={() => router.push(sessionHref)}>
                <Icon name="open_in_new" size={18} />
                {t("openSession")}
              </Button>
            )}
            {session.status === "UPCOMING" && (
              <Button variant="secondary" fullWidth onClick={() => setConfirming(true)}>
                <Icon name="event_busy" size={18} color="var(--heart)" />
                {tSchedule("cancelOccurrence")}
              </Button>
            )}
          </div>
        </div>
      </Popover>

      <ConfirmModal
        open={confirming}
        onClose={() => {
          setConfirming(false);
          onClose();
        }}
        onConfirm={() => cancelMutation.mutate()}
        icon="event_busy"
        title={tSchedule("cancelOccurrenceConfirmTitle")}
        body={`${session.templateName ?? tSchedule("unnamedTemplate")} · ${fmt.weekdayShort(day)}, ${fmt.shortDate(day)}${session.scheduledTime ? ` · ${fmt.time(new Date(`${session.scheduledFor}T${session.scheduledTime}`))}` : ""}. ${tSchedule("cancelOccurrenceConfirmBody")}`}
        cancelLabel={tSchedule("keepOccurrence")}
        confirmLabel={tSchedule("cancelOccurrenceConfirm")}
      />
    </>
  );
}
