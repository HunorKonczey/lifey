"use client";

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { ApiError } from "@/lib/api/client";
import { useToast } from "@/lib/hooks/useToast";
import { trainerApi } from "./api";
import { moveBody, type DropSlot } from "./calendarGrid";
import type { TrainerCalendarSessionResponse } from "./types";

/**
 * Moving one scheduled occurrence to a new slot (the PATCH endpoint) with the calendar's refresh and toasts — shared by the
 * drag-and-drop on the grid and the "Move…" dialog of the session peek, so both end the same way.
 */
export function useMoveOccurrence(onMoved?: () => void) {
  const t = useTranslations("admin.calendar");
  const tSchedule = useTranslations("admin.schedule");
  const queryClient = useQueryClient();
  const { show } = useToast();
  return useMutation({
    mutationFn: ({ session, slot }: { session: TrainerCalendarSessionResponse; slot: DropSlot }) => trainerApi.moveOccurrence(session.sessionId, moveBody(slot)),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["trainer-calendar"] });
      show(t("moved"), "success");
      onMoved?.();
    },
    onError: (e) => show(e instanceof ApiError && e.status === 422 ? tSchedule("horizonExceeded") : t("moveFailed"), "error"),
  });
}
