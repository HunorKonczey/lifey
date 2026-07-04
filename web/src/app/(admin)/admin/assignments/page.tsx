"use client";

import { useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { useQueries, useQuery } from "@tanstack/react-query";
import { format } from "date-fns";
import { trainerApi } from "@/features/trainer/api";
import { templateApi } from "@/features/workouts/api";
import { recipeApi } from "@/features/nutrition/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { ClientAvatar, nameFor } from "@/features/trainer/components/ClientAvatar";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import type { ContentType } from "@/features/trainer/types";

const CONTENT_ICON: Record<ContentType, string> = { TEMPLATE: "fitness_center", RECIPE: "restaurant" };

export default function AdminAssignmentsPage() {
  const t = useTranslations("admin.assignments");
  const [clientFilter, setClientFilter] = useState<number | "all">("all");
  const [typeFilter, setTypeFilter] = useState<ContentType | "all">("all");

  const clientsQ = useQuery({ queryKey: queryKeys.trainerClients.all(), queryFn: trainerApi.clients });
  const templatesQ = useQuery({ queryKey: queryKeys.workoutTemplates.all(), queryFn: templateApi.list });
  const recipesQ = useQuery({ queryKey: queryKeys.recipes.all(), queryFn: recipeApi.list });

  const clients = clientsQ.data ?? [];
  const assignmentQueries = useQueries({
    queries: clients.map((c) => ({
      queryKey: queryKeys.trainerAssignments.forClient(c.clientId),
      queryFn: () => trainerApi.assignmentsForClient(c.clientId),
      enabled: clients.length > 0,
    })),
  });

  const isLoading = clientsQ.isLoading || templatesQ.isLoading || recipesQ.isLoading || assignmentQueries.some((q) => q.isLoading);

  const sourceName = useMemo(() => {
    const map = new Map<string, string>();
    (templatesQ.data ?? []).forEach((tpl) => map.set(`TEMPLATE:${tpl.id}`, tpl.name));
    (recipesQ.data ?? []).forEach((r) => map.set(`RECIPE:${r.id}`, r.name));
    return (type: ContentType, sourceId: number) => map.get(`${type}:${sourceId}`) ?? t("unknownContent");
  }, [templatesQ.data, recipesQ.data, t]);

  const rows = useMemo(() => {
    const all = clients.flatMap((client, i) =>
      (assignmentQueries[i]?.data ?? []).map((a) => ({ ...a, client })),
    );
    return all
      .filter((r) => clientFilter === "all" || r.client.clientId === clientFilter)
      .filter((r) => typeFilter === "all" || r.contentType === typeFilter)
      .sort((a, b) => b.assignedAt.localeCompare(a.assignedAt));
  }, [clients, assignmentQueries, clientFilter, typeFilter]);

  if (isLoading) return <Skeleton variant="table" />;

  return (
    <div className="flex flex-col gap-3.5">
      <div className="flex items-center gap-2.5">
        <select
          value={clientFilter}
          onChange={(e) => setClientFilter(e.target.value === "all" ? "all" : Number(e.target.value))}
          className="h-10 rounded-xl px-3 text-sm font-semibold outline-none"
          style={{ background: "var(--surface)", color: "var(--on-surface)", border: "1px solid var(--outline)" }}
        >
          <option value="all">{t("allClients")}</option>
          {clients.map((c) => (
            <option key={c.clientId} value={c.clientId}>{nameFor(c.clientEmail)}</option>
          ))}
        </select>
        <select
          value={typeFilter}
          onChange={(e) => setTypeFilter(e.target.value as ContentType | "all")}
          className="h-10 rounded-xl px-3 text-sm font-semibold outline-none"
          style={{ background: "var(--surface)", color: "var(--on-surface)", border: "1px solid var(--outline)" }}
        >
          <option value="all">{t("allTypes")}</option>
          <option value="TEMPLATE">{t("typeTemplate")}</option>
          <option value="RECIPE">{t("typeRecipe")}</option>
        </select>
      </div>

      {rows.length === 0 ? (
        <EmptyState icon="assignment" title={t("noAssignments")} body={t("noAssignmentsBody")} />
      ) : (
        <div className="rounded-[var(--r-lg)] p-2 flex flex-col gap-1" style={{ background: "var(--surface)" }}>
          {rows.map((r) => (
            <div key={r.id} className="flex items-center gap-3.5 px-3.5 py-3 rounded-[13px]">
              <span className="text-xs tabular w-[70px] shrink-0" style={{ color: "var(--muted)" }}>
                {format(new Date(r.assignedAt), "yyyy-MM-dd")}
              </span>
              <ClientAvatar clientId={r.client.clientId} email={r.client.clientEmail} size={30} />
              <span className="text-[13px] font-bold w-[140px] shrink-0 truncate" style={{ color: "var(--on-surface)" }}>
                {nameFor(r.client.clientEmail)}
              </span>
              <span
                className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0"
                style={{ background: "var(--surface-container)", color: "var(--tertiary)" }}
              >
                <span className="material-symbols-rounded text-lg" style={{ fontVariationSettings: "'FILL' 1" }}>
                  {CONTENT_ICON[r.contentType]}
                </span>
              </span>
              <div className="flex-1 min-w-0">
                <p className="text-[13.5px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                  {sourceName(r.contentType, r.sourceId)}
                </p>
                <p className="text-[11px]" style={{ color: "var(--on-surface-variant)" }}>
                  {t(r.contentType === "TEMPLATE" ? "typeTemplate" : "typeRecipe")}
                </p>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
