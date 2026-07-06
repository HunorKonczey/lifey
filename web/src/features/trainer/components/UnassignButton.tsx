"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import type { ContentType } from "../types";

interface UnassignButtonProps {
  assignmentId: number;
  clientId: number;
  contentType: ContentType;
  sourceId: number;
  contentName: string;
}

/**
 * Removes a trainer's assignment and soft-deletes the copy it created in the
 * client's account (backend does both in one call) — used from both the
 * client-detail "assigned plans" list and the trainer-wide assignments table.
 */
export function UnassignButton({ assignmentId, clientId, contentType, sourceId, contentName }: UnassignButtonProps) {
  const t = useTranslations("admin.assignments");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [confirming, setConfirming] = useState(false);

  const unassignMutation = useMutation({
    mutationFn: () => trainerApi.unassign(assignmentId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerAssignments.forClient(clientId) });
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerAssignments.assignedClients(contentType, sourceId) });
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerClients.all() });
      show(t("unassigned"), "success");
    },
    onError: () => show(t("unassignFailed"), "error"),
  });

  return (
    <>
      <button
        onClick={() => setConfirming(true)}
        className="w-8 h-8 rounded-lg flex items-center justify-center shrink-0 transition-colors hover:bg-surface-high"
        style={{ color: "var(--error)" }}
        aria-label={t("unassign")}
        data-testid="unassign-button"
      >
        <span className="material-symbols-rounded text-lg">delete</span>
      </button>

      {confirming && (
        <div
          className="fixed inset-0 z-30 flex items-center justify-center p-4"
          style={{ background: "rgba(8,9,6,.6)" }}
          onClick={() => setConfirming(false)}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="w-full max-w-sm rounded-[var(--r-lg)] p-6"
            style={{ background: "var(--surface-container)", boxShadow: "0 18px 44px rgba(0,0,0,.4)" }}
          >
            <p className="text-base font-extrabold mb-2" style={{ color: "var(--on-surface)" }}>
              {t("unassignConfirmTitle")}
            </p>
            <p className="text-[12.5px] leading-relaxed mb-5" style={{ color: "var(--on-surface-variant)" }}>
              {t("unassignConfirmBody", { name: contentName })}
            </p>
            <div className="flex gap-2.5 justify-end">
              <button
                onClick={() => setConfirming(false)}
                className="text-sm font-bold px-4 py-2.5"
                style={{ color: "var(--on-surface-variant)" }}
              >
                {t("unassignCancel")}
              </button>
              <button
                onClick={() => {
                  setConfirming(false);
                  unassignMutation.mutate();
                }}
                disabled={unassignMutation.isPending}
                className="rounded-xl px-4.5 py-2.5 text-sm font-extrabold disabled:opacity-60"
                style={{ background: "var(--error)", color: "#161611" }}
              >
                {t("unassignConfirm")}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
