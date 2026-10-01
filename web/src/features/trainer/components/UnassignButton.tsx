"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { ConfirmModal, IconButton } from "@/components/ds";
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
 * Removes a trainer's assignment and soft-deletes the copy it created in the client's account (the backend does both in
 * one call) — used from the client page's "assigned plans" list and the trainer-wide assignments table. A DS icon button
 * and a `ConfirmModal` whose focus starts on "Mégse".
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
      <span data-testid="unassign-button" className="inline-flex">
        <IconButton icon="delete" label={t("unassign")} onClick={() => setConfirming(true)} />
      </span>
      <ConfirmModal
        open={confirming}
        onClose={() => setConfirming(false)}
        onConfirm={() => {
          setConfirming(false);
          unassignMutation.mutate();
        }}
        icon="delete"
        title={t("unassignConfirmTitle")}
        body={t("unassignConfirmBody", { name: contentName })}
        cancelLabel={t("unassignCancel")}
        confirmLabel={t("unassignConfirm")}
      />
    </>
  );
}
