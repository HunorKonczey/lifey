"use client";

import { useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { useQueries, useQuery } from "@tanstack/react-query";
import { SegmentedControl, SelectField } from "@/components/ds";
import { Skeleton } from "@/components/status/Skeleton";
import { EmptyState } from "@/components/status/EmptyState";
import { ErrorState } from "@/components/status/ErrorState";
import { trainerApi } from "@/features/trainer/api";
import { planItems, type PlanKind } from "@/features/trainer/assignedPlans";
import { AssignedPlanGroup } from "@/features/trainer/components/AssignedPlanGroup";
import { clientDisplayName } from "@/features/trainer/components/ClientAvatar";
import { recipeApi } from "@/features/nutrition/api";
import { templateApi } from "@/features/workouts/api";
import { queryKeys } from "@/lib/api/queryKeys";

type TypeFilter = "all" | PlanKind;

/**
 * Assigned plans by client (W9-C): one card per client with a row per program, template and recipe — type icon, name,
 * date, status chip, "⋯" → Visszavonás… with a confirmation. Filter by client and by type; clients with nothing
 * assigned are left out.
 */
export default function AdminAssignmentsPage() {
  const t = useTranslations("admin.assignments");
  const [clientFilter, setClientFilter] = useState<number | "all">("all");
  const [typeFilter, setTypeFilter] = useState<TypeFilter>("all");

  const clientsQ = useQuery({ queryKey: queryKeys.trainerClients.all(), queryFn: trainerApi.clients });
  const templatesQ = useQuery({ queryKey: queryKeys.workoutTemplates.all(), queryFn: templateApi.list });
  const recipesQ = useQuery({ queryKey: queryKeys.recipes.all(), queryFn: recipeApi.list });

  const clients = useMemo(() => clientsQ.data ?? [], [clientsQ.data]);
  const singleQueries = useQueries({
    queries: clients.map((c) => ({
      queryKey: queryKeys.trainerAssignments.forClient(c.clientId),
      queryFn: () => trainerApi.assignmentsForClient(c.clientId),
    })),
  });
  const programQueries = useQueries({
    queries: clients.map((c) => ({
      queryKey: queryKeys.trainerProgramAssignments.forClient(c.clientId),
      queryFn: () => trainerApi.programAssignmentsForClient(c.clientId),
    })),
  });

  const isLoading = clientsQ.isLoading || templatesQ.isLoading || recipesQ.isLoading || singleQueries.some((q) => q.isLoading) || programQueries.some((q) => q.isLoading);
  const isError = clientsQ.isError || singleQueries.some((q) => q.isError) || programQueries.some((q) => q.isError);

  const groups = useMemo(() => {
    const names = new Map<string, string>();
    (templatesQ.data ?? []).forEach((tpl) => names.set(`TEMPLATE:${tpl.id}`, tpl.name));
    (recipesQ.data ?? []).forEach((r) => names.set(`RECIPE:${r.id}`, r.name));
    const sourceName = (kind: "TEMPLATE" | "RECIPE", id: number) => names.get(`${kind}:${id}`) ?? t("unknownContent");
    const now = new Date();
    const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
    return clients
      .map((client, i) => ({
        client,
        items: planItems(singleQueries[i]?.data ?? [], programQueries[i]?.data ?? [], sourceName, today).filter((it) => typeFilter === "all" || it.kind === typeFilter),
      }))
      .filter((g) => g.items.length > 0 && (clientFilter === "all" || g.client.clientId === clientFilter));
  }, [clients, singleQueries, programQueries, templatesQ.data, recipesQ.data, clientFilter, typeFilter, t]);

  if (isLoading) return <Skeleton variant="table" />;
  if (isError) return <ErrorState onRetry={() => clientsQ.refetch()} />;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-3">
        <SelectField
          size="dense"
          aria-label={t("allClients")}
          value={clientFilter}
          onChange={(e) => setClientFilter(e.target.value === "all" ? "all" : Number(e.target.value))}
        >
          <option value="all">{t("allClients")}</option>
          {clients.map((c) => (
            <option key={c.clientId} value={c.clientId}>{clientDisplayName(c)}</option>
          ))}
        </SelectField>
        <SegmentedControl
          aria-label={t("allTypes")}
          value={typeFilter}
          onChange={setTypeFilter}
          options={[
            { value: "all", label: t("allTypes") },
            { value: "PROGRAM", label: t("typeProgram") },
            { value: "TEMPLATE", label: t("typeTemplate") },
            { value: "RECIPE", label: t("typeRecipe") },
          ]}
        />
      </div>

      {groups.length === 0 ? (
        <EmptyState icon="assignment" title={t("noAssignments")} body={t("noAssignmentsBody")} />
      ) : (
        groups.map((g) => (
          <AssignedPlanGroup key={g.client.clientId} clientId={g.client.clientId} name={clientDisplayName(g.client)} email={g.client.clientEmail} items={g.items} />
        ))
      )}
    </div>
  );
}
