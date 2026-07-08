"use client";

import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { useLocale } from "@/lib/hooks/useLocale";
import { ClientAvatar, nameFor } from "./ClientAvatar";
import { RecurrenceLabel } from "./RecurrenceLabel";
import { STATUS_STYLE } from "../scheduleStatus";
import type { TrainerCalendarSessionResponse } from "../types";

const DATE_LOCALES = { en: enUS, hu } as const;
const POPOVER_WIDTH = 340;

function computePosition(anchorEl: HTMLElement) {
  const rect = anchorEl.getBoundingClientRect();
  const gap = 12;
  let left = rect.right + gap;
  if (left + POPOVER_WIDTH > window.innerWidth - 12) {
    left = rect.left - POPOVER_WIDTH - gap;
  }
  left = Math.min(Math.max(12, left), window.innerWidth - POPOVER_WIDTH - 12);
  const top = Math.min(Math.max(12, rect.top), Math.max(12, window.innerHeight - 12 - 420));
  return { top, left };
}

interface CalendarSessionPeekProps {
  session: TrainerCalendarSessionResponse;
  anchorEl: HTMLElement;
  onClose: () => void;
}

/**
 * Anchored popover for a calendar session (design: C frame) — not a modal.
 * Render with `key={session.sessionId}` from the parent so switching to a
 * different session's anchor always remounts (and re-measures) fresh.
 */
export function CalendarSessionPeek({ session, anchorEl, onClose }: CalendarSessionPeekProps) {
  const t = useTranslations("admin.calendar");
  const tSchedule = useTranslations("admin.schedule");
  const dateLocale = DATE_LOCALES[useLocale((s) => s.locale)];
  const router = useRouter();
  const queryClient = useQueryClient();
  const { show } = useToast();

  const popoverRef = useRef<HTMLDivElement>(null);
  const [pos] = useState(() => computePosition(anchorEl));
  const [confirming, setConfirming] = useState(false);

  useEffect(() => {
    popoverRef.current?.focus();
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    const onPointerDown = (e: MouseEvent) => {
      if (popoverRef.current && !popoverRef.current.contains(e.target as Node) && e.target !== anchorEl) {
        onClose();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    window.addEventListener("mousedown", onPointerDown);
    return () => {
      window.removeEventListener("keydown", onKeyDown);
      window.removeEventListener("mousedown", onPointerDown);
    };
  }, [onClose, anchorEl]);

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
  const clientName = nameFor(session.clientEmail);
  const scheduleHref = `/admin/clients/${session.clientId}?tab=schedule`;
  const sessionHref = `/admin/clients/${session.clientId}?tab=workouts&focusSessionId=${session.sessionId}`;

  return createPortal(
    <div
      ref={popoverRef}
      role="dialog"
      aria-label={t("peekTitle")}
      tabIndex={-1}
      className="fixed z-50 rounded-[20px] p-[18px] outline-none"
      style={{
        top: pos.top,
        left: pos.left,
        width: POPOVER_WIDTH,
        background: "var(--surface-highest)",
        boxShadow: "0 24px 60px rgba(0,0,0,.55)",
      }}
    >
      {confirming ? (
        <>
          <div className="flex flex-col items-center text-center gap-3 py-1">
            <div
              className="w-14 h-14 rounded-2xl flex items-center justify-center"
              style={{ background: "var(--error-container)", color: "var(--error)" }}
            >
              <span className="material-symbols-rounded text-3xl">event_busy</span>
            </div>
            <p className="text-base font-extrabold" style={{ color: "var(--on-surface)" }}>
              {tSchedule("cancelOccurrenceConfirmTitle")}
            </p>
            <p className="text-[12.5px] leading-relaxed" style={{ color: "var(--on-surface-variant)" }}>
              {session.templateName ?? tSchedule("unnamedTemplate")} ·{" "}
              {format(new Date(`${session.scheduledFor}T00:00:00`), "EEEE, MMM d.", { locale: dateLocale })}
              {session.scheduledTime && ` · ${session.scheduledTime.slice(0, 5)}`}
              <br />
              {tSchedule("cancelOccurrenceConfirmBody")}
            </p>
          </div>
          <div className="flex flex-col gap-2 mt-4">
            <button
              onClick={() => cancelMutation.mutate()}
              disabled={cancelMutation.isPending}
              className="rounded-2xl py-3 text-sm font-extrabold disabled:opacity-60"
              style={{ background: "var(--error)", color: "#161611" }}
            >
              {tSchedule("cancelOccurrenceConfirm")}
            </button>
            <button
              onClick={() => setConfirming(false)}
              className="rounded-2xl py-3 text-sm font-bold"
              style={{ color: "var(--on-surface)" }}
            >
              {tSchedule("keepOccurrence")}
            </button>
          </div>
        </>
      ) : (
        <>
          <div className="flex items-center gap-3">
            <ClientAvatar clientId={session.clientId} email={session.clientEmail} size={42} />
            <div className="flex-1 min-w-0">
              <p className="text-[15px] font-extrabold truncate" style={{ color: "var(--on-surface)" }}>
                {clientName}
              </p>
              <p className="text-[11.5px] truncate mt-0.5" style={{ color: "var(--on-surface-variant)" }}>
                {session.clientEmail}
              </p>
            </div>
            <button onClick={onClose} aria-label={t("close")} style={{ color: "var(--on-surface-variant)" }}>
              <span className="material-symbols-rounded text-xl">close</span>
            </button>
          </div>

          <div className="h-px my-3.5" style={{ background: "var(--outline)" }} />

          <div className="flex flex-col gap-2.5">
            <div className="flex items-center gap-2.5">
              <span className="material-symbols-rounded text-[17px]" style={{ color: "var(--tertiary)" }}>
                fitness_center
              </span>
              <span className="text-[13.5px] font-bold" style={{ color: "var(--on-surface)" }}>
                {session.templateName ?? tSchedule("unnamedTemplate")}
              </span>
            </div>
            <div className="flex items-center gap-2.5">
              <span className="material-symbols-rounded text-[17px]" style={{ color: "var(--on-surface-variant)" }}>
                event
              </span>
              <span className="text-[13px] font-semibold" style={{ color: "var(--on-surface)" }}>
                {format(new Date(`${session.scheduledFor}T00:00:00`), "EEEE, MMM d.", { locale: dateLocale })}
                {session.scheduledTime && (
                  <> · <span className="font-extrabold tabular">{session.scheduledTime.slice(0, 5)}</span></>
                )}
              </span>
              <span
                className="flex items-center gap-1 rounded-full text-[10.5px] font-extrabold px-2.5 py-1 shrink-0"
                style={{ background: style.bg, color: style.color, border: style.bg === "transparent" ? "1px solid var(--outline)" : "none" }}
              >
                <span className="material-symbols-rounded text-sm" style={{ fontVariationSettings: style.fill ? "'FILL' 1" : "'FILL' 0" }}>
                  {style.icon}
                </span>
                {tSchedule(`status.${session.status}`)}
              </span>
            </div>
            {schedule && (
              <div className="flex items-start gap-2.5">
                <span className="material-symbols-rounded text-[17px]" style={{ color: "var(--on-surface-variant)" }}>
                  event_repeat
                </span>
                <span className="text-[12.5px] leading-relaxed" style={{ color: "var(--on-surface-variant)" }}>
                  <RecurrenceLabel
                    recurrence={schedule.recurrence}
                    daysOfWeek={schedule.daysOfWeek}
                    timeOfDay={schedule.timeOfDay}
                    startDate={schedule.startDate}
                    endDate={schedule.endDate}
                  />
                </span>
              </div>
            )}
          </div>

          <div className="h-px my-3.5" style={{ background: "var(--outline)" }} />

          <div className="flex flex-col gap-2">
            <button
              onClick={() => router.push(scheduleHref)}
              className="flex items-center gap-2 rounded-xl px-3.5 py-2.5 text-[13px] font-bold"
              style={{ color: "var(--on-tertiary-container)", border: "1px solid var(--outline)" }}
            >
              <span className="material-symbols-rounded text-lg">open_in_new</span>
              {t("clientSchedule")}
            </button>
            {session.status === "DONE" && (
              <button
                onClick={() => router.push(sessionHref)}
                className="flex items-center gap-2 rounded-xl px-3.5 py-2.5 text-[13px] font-extrabold"
                style={{ background: "var(--tertiary-container)", color: "var(--on-tertiary-container)" }}
              >
                <span className="material-symbols-rounded text-lg">open_in_new</span>
                {t("openSession")}
              </button>
            )}
            {session.status === "UPCOMING" && (
              <button
                onClick={() => setConfirming(true)}
                className="flex items-center gap-2 rounded-xl px-3.5 py-2.5 text-[13px] font-extrabold"
                style={{ background: "var(--error-container)", color: "var(--error)" }}
              >
                <span className="material-symbols-rounded text-lg">event_busy</span>
                {tSchedule("cancelOccurrence")}
              </button>
            )}
          </div>
        </>
      )}
    </div>,
    document.body,
  );
}
