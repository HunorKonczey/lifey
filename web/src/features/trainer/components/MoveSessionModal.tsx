"use client";

import { useState } from "react";
import { format } from "date-fns";
import { useTranslations } from "next-intl";
import { Button, DateFields, Modal, TimeField } from "@/components/ds";
import { isSameSlot, moveDateProblem, slotFromInput } from "../calendarGrid";
import { useMoveOccurrence } from "../useMoveOccurrence";
import type { TrainerCalendarSessionResponse } from "../types";

interface MoveSessionModalProps {
  session: TrainerCalendarSessionResponse;
  /** "Anna · Upper body", the line that says which workout this is. */
  summary: string;
  onClose: () => void;
}

/**
 * "Move…" (LIF-140): pick a new day and time for one upcoming occurrence with the keyboard (or a finger) — what dragging
 * the card onto another cell does with a pointer. The day is checked the way the backend checks it (today up to three
 * months ahead); an empty time means "no time of day". Closes itself once the move went through.
 */
export function MoveSessionModal({ session, summary, onClose }: MoveSessionModalProps) {
  const t = useTranslations("admin.calendar");
  const tSchedule = useTranslations("admin.schedule");
  const today = format(new Date(), "yyyy-MM-dd");
  const [date, setDate] = useState(session.scheduledFor);
  const [time, setTime] = useState(session.scheduledTime ? session.scheduledTime.slice(0, 5) : "");
  const move = useMoveOccurrence(onClose);

  const slot = slotFromInput(date, time);
  const problem = moveDateProblem(date, today);
  const unchanged = isSameSlot(session, slot);
  const error = problem === "horizon" ? tSchedule("horizonExceeded") : problem ? tSchedule("dateInvalid") : undefined;

  return (
    <Modal open onClose={onClose} width={480} aria-label={t("moveTitle")}>
      <form
        className="flex flex-col gap-4 p-6"
        onSubmit={(e) => {
          e.preventDefault();
          if (!problem && !unchanged && !move.isPending) move.mutate({ session, slot });
        }}
      >
        <div className="flex flex-col gap-1">
          <h2 className="type-title-l">{t("moveTitle")}</h2>
          <p className="type-body-s" style={{ color: "var(--text-2)" }}>{summary}</p>
        </div>
        <DateFields
          label={tSchedule("date")}
          value={date ? new Date(`${date}T00:00:00`) : null}
          onChange={(d) => setDate(d ? format(d, "yyyy-MM-dd") : "")}
          error={error}
        />
        <TimeField label={tSchedule("timeOfDay")} value={time} onChange={setTime} quickTimes={["07:00", "17:30", "18:00"]} />
        <div className="flex justify-end gap-2 pt-1">
          <Button type="button" variant="secondary" onClick={onClose}>{t("moveCancel")}</Button>
          <Button type="submit" disabled={Boolean(problem) || unchanged || move.isPending} data-testid="calendar-move-apply">{t("moveApply")}</Button>
        </div>
      </form>
    </Modal>
  );
}
