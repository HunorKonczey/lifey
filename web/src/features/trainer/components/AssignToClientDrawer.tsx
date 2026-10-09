"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { ErrorState } from "@/components/status/ErrorState";
import { normalizeForSearch } from "@/lib/utils/search";
import { useTrainerBillingGate } from "@/features/billing/hooks";
import { BillingBlockedDialog } from "@/features/billing/components/BillingBlockedDialog";
import { ClientAvatar, clientDisplayName } from "./ClientAvatar";
import type { ContentType } from "../types";
import { Button, Icon, TextField } from "@/components/ds";
import { Drawer } from "@/components/ds/overlay/Drawer";

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
  const gate = useTrainerBillingGate();
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
    normalizeForSearch(c.clientEmail).includes(normalizedSearch) || normalizeForSearch(clientDisplayName(c)).includes(normalizedSearch),
  );

  const toggleClient = (clientId: number) => {
    if (assignedClientIds.has(clientId)) return;
    setSelectedClientIds((prev) =>
      prev.includes(clientId) ? prev.filter((id) => id !== clientId) : [...prev, clientId],
    );
  };

  const newClientIds = selectedClientIds.filter((id) => !assignedClientIds.has(id));

  const assignMutation = useMutation({
    mutationFn: (clientIds: number[]) => trainerApi.assign({ clientIds, contentType, sourceId }),
    onSuccess: (response, clientIds) => {
      clientIds.forEach((clientId) => {
        queryClient.invalidateQueries({ queryKey: queryKeys.trainerAssignments.forClient(clientId) });
      });
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerAssignments.assignedClients(contentType, sourceId) });
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerTemplates.usage() });

      const assignedCount = response.assignments.length;
      const skippedCount = response.skippedClientIds.length;
      if (skippedCount === 0) {
        if (assignedCount === 1) {
          const client = clientsQ.data?.find((c) => c.clientId === response.assignments[0].clientId);
          show(t("assigned", { name: client ? clientDisplayName(client) : "" }), "success");
        } else {
          show(t("assignedMultiple", { count: assignedCount }), "success");
        }
      } else {
        show(t("assignedWithSkipped", { assigned: assignedCount, skipped: skippedCount }), "success");
      }
      onClose();
    },
    onError: () => {
      // A stale roster (revoked client) fails the whole batch — refresh the client list.
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerClients.all() });
      show(t("assignFailed"), "error");
    },
  });

  // D-T5: the trigger button that opens this drawer stays visible and
  // enabled-looking; a blocked trainer sees this dialog the moment it would
  // have opened, instead of filling out a form that can only fail.
  if (gate.state !== "OK") {
    return (
      <BillingBlockedDialog
        open
        onClose={onClose}
        reason={gate.state === "RESTRICTED" ? "restricted" : "overLimit"}
        currentPlan={gate.currentPlan}
        activeClients={gate.activeClients}
        maxClients={gate.maxClients}
      />
    );
  }

  return (
    <Drawer
      open
      onClose={onClose}
      width={480}
      title={t("drawerTitle", { name: title })}
      isDirty={newClientIds.length > 0}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            {t("cancel")}
          </Button>
          <Button
            onClick={() => assignMutation.mutate(newClientIds)}
            disabled={newClientIds.length === 0 || assignMutation.isPending}
            data-testid="assign-drawer-submit"
          >
            {assignMutation.isPending ? t("assigning") : newClientIds.length > 1 ? t("assignCount", { count: newClientIds.length }) : t("assign")}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4" data-testid="assign-to-client-drawer">
        <TextField leadingIcon="search" value={search} onChange={(e) => setSearch(e.target.value)} placeholder={t("searchClientPlaceholder")} aria-label={t("searchClientPlaceholder")} />

        <div className="flex max-h-[320px] flex-col gap-1 overflow-y-auto">
          {clientsQ.isError ? (
            <ErrorState inline onRetry={() => clientsQ.refetch()} />
          ) : filteredClients.length === 0 ? (
            <p className="type-body-s py-4 text-center" style={{ color: "var(--text-3)" }}>{t("noClientsFound")}</p>
          ) : (
            filteredClients.map((c) => {
              const selected = selectedClientIds.includes(c.clientId);
              const locked = assignedClientIds.has(c.clientId);
              return (
                <button
                  key={c.clientId}
                  type="button"
                  data-testid="assign-drawer-client-row"
                  onClick={() => toggleClient(c.clientId)}
                  disabled={locked}
                  aria-pressed={selected}
                  className="lifey-button flex items-center gap-3 px-3 py-2.5 text-left disabled:cursor-default"
                  style={{
                    borderRadius: "var(--r-control)",
                    background: selected && !locked ? "color-mix(in srgb, var(--primary) 14%, transparent)" : "transparent",
                    boxShadow: selected && !locked ? "inset 0 0 0 2px var(--primary)" : "none",
                  }}
                >
                  <ClientAvatar clientId={c.clientId} email={c.clientEmail} size={32} />
                  <span className="min-w-0 flex-1">
                    <span className="type-body-s block truncate" style={{ fontWeight: 700 }}>{clientDisplayName(c)}</span>
                    {locked && <span className="type-body-s block" style={{ color: "var(--text-3)" }}>{t("alreadyAssignedBadge")}</span>}
                  </span>
                  {selected ? (
                    <Icon name="check_circle" size={22} fill={1} color={locked ? "var(--text-3)" : "var(--primary)"} />
                  ) : (
                    <span className="h-[18px] w-[18px] shrink-0 rounded-full" style={{ boxShadow: "inset 0 0 0 1.5px var(--hairline)" }} />
                  )}
                </button>
              );
            })
          )}
        </div>

        <div className="p-4" style={{ borderRadius: "var(--r-control)", background: "var(--nested)" }}>
          <p className="type-overline mb-2.5" style={{ color: "var(--text-3)" }}>{t("content")}</p>
          <div className="flex flex-col gap-2">
            {summary.map((row, i) => (
              <div key={i} className="type-body-s flex items-center justify-between gap-3">
                <span style={{ fontWeight: 700 }}>{row.label}</span>
                <span className="tabular" style={{ color: "var(--text-2)" }}>{row.detail}</span>
              </div>
            ))}
            {moreCount > 0 && <p className="type-body-s" style={{ color: "var(--text-3)" }}>{t("moreItems", { count: moreCount })}</p>}
          </div>
        </div>
      </div>
    </Drawer>
  );
}
