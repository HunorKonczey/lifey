"use client";

import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useTranslations } from "next-intl";
import { Avatar, ConfirmModal, Icon, RowMenuButton, TintedChip, colorForSeed } from "@/components/ds";
import { queryKeys } from "@/lib/api/queryKeys";
import { useFormat } from "@/lib/i18n/format";
import { useToast } from "@/lib/hooks/useToast";
import { trainerApi } from "../api";
import type { PlanItem, PlanKind, PlanStatus } from "../assignedPlans";

const KIND_ICON: Record<PlanKind, string> = { PROGRAM: "view_week", TEMPLATE: "fitness_center", RECIPE: "menu_book" };
const STATUS_COLOR: Record<PlanStatus, string> = { ACTIVE: "var(--primary)", DONE: "var(--text-2)", SCHEDULED: "var(--m-water)" };

interface Props {
  clientId: number;
  name: string;
  email: string;
  items: PlanItem[];
}

/**
 * One client's block of the assigned-plans page (W9-C): avatar, name and "3 tétel", then a row per plan — a type icon
 * (program / template / recipe), the name, the date or span, a status chip (Aktív · Kész · Ütemezve) and, for a
 * program with missed workouts, a heart "Kimaradt" chip. "⋯" → "Visszavonás…" asks first (focus starts on "Mégse").
 */
export function AssignedPlanGroup({ clientId, name, email, items }: Props) {
  const t = useTranslations("admin.assignments");
  const fmt = useFormat();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [revoking, setRevoking] = useState<PlanItem | null>(null);

  const revokeMutation = useMutation({
    mutationFn: (item: PlanItem) => (item.kind === "PROGRAM" ? trainerApi.cancelProgramAssignment(item.id) : trainerApi.unassign(item.id)),
    onSuccess: (_, item) => {
      if (item.kind === "PROGRAM") {
        queryClient.invalidateQueries({ queryKey: queryKeys.trainerProgramAssignments.forClient(clientId) });
        queryClient.invalidateQueries({ queryKey: queryKeys.trainerPrograms.all() });
      } else {
        queryClient.invalidateQueries({ queryKey: queryKeys.trainerAssignments.forClient(clientId) });
        if (item.sourceId != null) queryClient.invalidateQueries({ queryKey: queryKeys.trainerAssignments.assignedClients(item.kind, item.sourceId) });
      }
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerClients.all() });
      show(t("revoked"), "success");
      setRevoking(null);
    },
    onError: () => show(t("unassignFailed"), "error"),
  });

  const dateText = (item: PlanItem) => (item.to ? `${fmt.date(item.from, "day")} – ${fmt.date(item.to, "day")}` : fmt.date(item.from, "dayYear"));

  return (
    <section className="p-2" style={{ borderRadius: "var(--r-card)", background: "var(--card)", boxShadow: "var(--e1), var(--edge-card)" }} data-testid="assigned-plan-group" aria-label={name}>
      <header className="flex items-center gap-3 px-3.5 py-3">
        <Avatar name={name} email={email} size={32} color={colorForSeed(String(clientId))} />
        <h2 className="type-title min-w-0 flex-1 truncate">{name}</h2>
        <span className="type-body-s" style={{ color: "var(--text-3)" }}>{t("itemCount", { count: items.length })}</span>
      </header>
      <ul>
        {items.map((item) => (
          <li key={`${item.kind}-${item.id}`} data-testid="assigned-plan-row" className="flex flex-wrap items-center gap-x-3.5 gap-y-2 px-3.5 py-2.5" style={{ borderTop: "1px solid var(--hairline)" }}>
            <span className="flex h-9 w-9 shrink-0 items-center justify-center" style={{ borderRadius: "var(--r-tag)", background: "var(--nested)" }}>
              <Icon name={KIND_ICON[item.kind]} size={20} fill={1} color="var(--role)" />
            </span>
            <span className="min-w-0 flex-1 basis-[150px]">
              <span className="type-body block truncate" style={{ fontWeight: 700 }}>{item.name}</span>
              <span className="type-body-s block tabular" style={{ color: "var(--text-3)" }}>{dateText(item)}</span>
            </span>
            <span className="flex shrink-0 flex-wrap items-center justify-end gap-1.5">
              {item.missed > 0 && <TintedChip label={t("missedChip", { count: item.missed })} color="var(--heart)" icon="event_busy" />}
              <TintedChip label={t(`status.${item.status}`)} color={STATUS_COLOR[item.status]} />
            </span>
            <RowMenuButton
              label={t("rowMenuAria", { name: item.name })}
              items={[{ label: t("revoke"), icon: "undo", destructive: true, onSelect: () => setRevoking(item) }]}
            />
          </li>
        ))}
      </ul>

      <ConfirmModal
        open={revoking !== null}
        onClose={() => setRevoking(null)}
        onConfirm={() => revoking && revokeMutation.mutate(revoking)}
        icon="undo"
        title={t("revokeConfirmTitle")}
        body={t(revoking?.kind === "PROGRAM" ? "revokeProgramBody" : "unassignConfirmBody", { name: revoking?.name ?? "" })}
        cancelLabel={t("unassignCancel")}
        confirmLabel={t("revokeConfirm")}
      />
    </section>
  );
}
