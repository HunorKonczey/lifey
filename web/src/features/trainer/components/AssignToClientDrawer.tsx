"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { trainerApi } from "../api";
import { ApiError } from "@/lib/api/client";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { ErrorState } from "@/components/status/ErrorState";
import { normalizeForSearch } from "@/lib/utils/search";
import { ClientAvatar, nameFor } from "./ClientAvatar";
import type { ContentType } from "../types";

export interface AssignSummaryRow {
  label: string;
  detail: string;
}

interface AssignToClientDrawerProps {
  contentType: ContentType;
  sourceId: number;
  title: string;
  summary: AssignSummaryRow[];
  moreCount?: number;
  onClose: () => void;
}

export function AssignToClientDrawer({
  contentType, sourceId, title, summary, moreCount = 0, onClose,
}: AssignToClientDrawerProps) {
  const t = useTranslations("admin.assignDrawer");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [search, setSearch] = useState("");
  const [selectedClientIds, setSelectedClientIds] = useState<number[]>([]);
  const hasSeededSelection = useRef(false);

  const clientsQ = useQuery({ queryKey: queryKeys.trainerClients.all(), queryFn: trainerApi.clients });
  const assignedClientIdsQ = useQuery({
    queryKey: queryKeys.trainerAssignments.assignedClients(contentType, sourceId),
    queryFn: () => trainerApi.assignedClientIds(contentType, sourceId),
  });
  const assignedClientIds = new Set(assignedClientIdsQ.data ?? []);

  // Pre-check clients who already have this content, once, so the trainer sees
  // at a glance who has it — their checkbox is then locked, since re-assigning
  // the same content to the same client is rejected by the backend.
  useEffect(() => {
    if (!hasSeededSelection.current && assignedClientIdsQ.data) {
      setSelectedClientIds(assignedClientIdsQ.data);
      hasSeededSelection.current = true;
    }
  }, [assignedClientIdsQ.data]);

  const normalizedSearch = normalizeForSearch(search);
  const filteredClients = (clientsQ.data ?? []).filter((c) =>
    normalizeForSearch(c.clientEmail).includes(normalizedSearch) || normalizeForSearch(nameFor(c.clientEmail)).includes(normalizedSearch),
  );

  const toggleClient = (clientId: number) => {
    if (assignedClientIds.has(clientId)) return;
    setSelectedClientIds((prev) =>
      prev.includes(clientId) ? prev.filter((id) => id !== clientId) : [...prev, clientId],
    );
  };

  const newClientIds = selectedClientIds.filter((id) => !assignedClientIds.has(id));

  const assignMutation = useMutation({
    mutationFn: async (clientIds: number[]) => {
      const results = await Promise.allSettled(
        clientIds.map((clientId) => trainerApi.assign({ clientId, contentType, sourceId })),
      );
      return { clientIds, results };
    },
    onSuccess: ({ clientIds, results }) => {
      clientIds.forEach((clientId) => {
        queryClient.invalidateQueries({ queryKey: queryKeys.trainerAssignments.forClient(clientId) });
      });
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerAssignments.assignedClients(contentType, sourceId) });
      const failed = results.filter((r) => r.status === "rejected");
      const failedCount = failed.length;
      const succeededCount = clientIds.length - failedCount;
      const allFailedWereDuplicates =
        failedCount > 0 && failed.every((r) => r.reason instanceof ApiError && r.reason.status === 409);
      if (failedCount === 0) {
        if (clientIds.length === 1) {
          const client = clientsQ.data?.find((c) => c.clientId === clientIds[0]);
          show(t("assigned", { name: client ? nameFor(client.clientEmail) : "" }), "success");
        } else {
          show(t("assignedMultiple", { count: succeededCount }), "success");
        }
        onClose();
      } else if (succeededCount === 0) {
        show(allFailedWereDuplicates ? t("alreadyAssignedFailed") : t("assignFailed"), "error");
      } else {
        show(
          allFailedWereDuplicates
            ? t("assignedPartialAlreadyAssigned", { succeeded: succeededCount, failed: failedCount })
            : t("assignedPartial", { succeeded: succeededCount, failed: failedCount }),
          "error",
        );
      }
    },
    onError: () => show(t("assignFailed"), "error"),
  });

  return (
    <div className="fixed inset-0 z-50 flex justify-end" data-testid="assign-to-client-drawer">
      <div className="absolute inset-0" style={{ background: "rgba(8,9,6,.45)" }} onClick={onClose} />
      <div
        className="relative w-full max-w-[420px] h-full flex flex-col gap-4 p-5.5 overflow-y-auto"
        style={{ background: "var(--surface-container)", boxShadow: "-20px 0 50px rgba(0,0,0,.45)" }}
      >
        <div className="flex items-center justify-between">
          <p className="text-lg font-extrabold tracking-tight" style={{ color: "var(--on-surface)" }}>
            {t("drawerTitle", { name: title })}
          </p>
          <button onClick={onClose} style={{ color: "var(--on-surface-variant)" }} aria-label={t("close")}>
            <span className="material-symbols-rounded text-xl">close</span>
          </button>
        </div>

        <div className="rounded-2xl h-12 flex items-center gap-2.5 px-4.5" style={{ background: "var(--surface)" }} data-ring-frame>
          <span className="material-symbols-rounded text-lg" style={{ color: "var(--muted)" }}>search</span>
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t("searchClientPlaceholder")}
            className="flex-1 bg-transparent outline-none text-sm"
            style={{ color: "var(--on-surface)" }}
          />
        </div>

        <div className="flex flex-col gap-1.5 max-h-[240px] overflow-y-auto">
          {clientsQ.isError ? (
            <ErrorState inline onRetry={() => clientsQ.refetch()} />
          ) : filteredClients.length === 0 ? (
            <p className="text-xs text-center py-4" style={{ color: "var(--muted)" }}>{t("noClientsFound")}</p>
          ) : (
            filteredClients.map((c) => {
              const selected = selectedClientIds.includes(c.clientId);
              const locked = assignedClientIds.has(c.clientId);
              return (
                <button
                  key={c.clientId}
                  data-testid="assign-drawer-client-row"
                  onClick={() => toggleClient(c.clientId)}
                  disabled={locked}
                  className="flex items-center gap-3 rounded-2xl px-3 py-2.5 transition-colors text-left disabled:cursor-default"
                  style={{
                    background: selected ? "rgba(110,154,106,.14)" : "transparent",
                    border: selected ? "1.5px solid var(--tertiary)" : "1.5px solid transparent",
                  }}
                >
                  <ClientAvatar clientId={c.clientId} email={c.clientEmail} size={32} />
                  <span className="flex-1 min-w-0">
                    <span className="block text-[13.5px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                      {nameFor(c.clientEmail)}
                    </span>
                    {locked && (
                      <span className="block text-[11px]" style={{ color: "var(--muted)" }}>
                        {t("alreadyAssignedBadge")}
                      </span>
                    )}
                  </span>
                  {selected ? (
                    <span
                      className="material-symbols-rounded text-xl"
                      style={{ color: locked ? "var(--muted)" : "var(--tertiary)", fontVariationSettings: "'FILL' 1" }}
                    >
                      check_circle
                    </span>
                  ) : (
                    <span className="w-[18px] h-[18px] rounded-full shrink-0" style={{ border: "1.5px solid var(--outline)" }} />
                  )}
                </button>
              );
            })
          )}
        </div>

        <div className="rounded-2xl p-4" style={{ background: "var(--surface)" }}>
          <p className="text-[11px] font-bold tracking-wider uppercase mb-2.5" style={{ color: "var(--muted)" }}>
            {t("content")}
          </p>
          <div className="flex flex-col gap-2">
            {summary.map((row, i) => (
              <div key={i} className="flex items-center justify-between text-[12.5px]">
                <span className="font-semibold" style={{ color: "var(--on-surface)" }}>{row.label}</span>
                <span className="tabular" style={{ color: "var(--on-surface-variant)" }}>{row.detail}</span>
              </div>
            ))}
            {moreCount > 0 && (
              <p className="text-[11px]" style={{ color: "var(--muted)" }}>{t("moreItems", { count: moreCount })}</p>
            )}
          </div>
        </div>

        <div className="mt-auto flex gap-2.5 pt-2">
          <button onClick={onClose} className="flex-1 text-center text-[13.5px] font-bold py-3 rounded-2xl" style={{ color: "var(--on-surface-variant)" }}>
            {t("cancel")}
          </button>
          <button
            onClick={() => assignMutation.mutate(newClientIds)}
            disabled={newClientIds.length === 0 || assignMutation.isPending}
            data-testid="assign-drawer-submit"
            className="flex-[2] text-center rounded-2xl py-3 text-[13.5px] font-extrabold disabled:opacity-40"
            style={{ background: "var(--tertiary)", color: "#161611" }}
          >
            {assignMutation.isPending
              ? t("assigning")
              : newClientIds.length > 1
                ? t("assignCount", { count: newClientIds.length })
                : t("assign")}
          </button>
        </div>
      </div>
    </div>
  );
}
