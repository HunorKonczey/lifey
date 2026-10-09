"use client";

import { useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQueries, useQuery, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { ApiError } from "@/lib/api/client";
import { useToast } from "@/lib/hooks/useToast";
import { Button, Checkbox, DateFields, Drawer, Icon, TextField } from "@/components/ds";
import { ErrorState } from "@/components/status/ErrorState";
import { useFormat } from "@/lib/format/useFormat";
import { useTrainerBillingGate } from "@/features/billing/hooks";
import { BillingBlockedDialog } from "@/features/billing/components/BillingBlockedDialog";
import { complianceFor } from "../compliance";
import { consequenceSummary, findConflicts, programOccurrences } from "../programConflicts";
import { isValidProgramStartDate, nextOrSameMonday } from "../program";
import { ClientAvatar, clientDisplayName } from "./ClientAvatar";

interface AssignProgramDrawerProps {
  /* Client-detail entry point: the client is fixed, the trainer picks a program. */
  clientId?: number;
  clientName?: string;
  /* Program list/builder entry point: the program is fixed, the trainer picks the clients. */
  programId?: number;
  programName?: string;
  onClose: () => void;
}

const iso = (d: Date) => format(d, "yyyy-MM-dd");

/**
 * "Program kiosztása" (W8-C), on the Drawer primitive: pick the program (or it is fixed), tick the clients it goes to —
 * each marked "már használja" (disabled), "aktív" or a heart "6 napja inaktív" — a Monday to start on, and read what it
 * will do before pressing the button: how many workouts land in the calendar between which days, and which of the
 * client's existing workouts clash (within 60 minutes). Conflicts are listed, never auto-shifted. One request per client.
 */
export function AssignProgramDrawer({ clientId: fixedClientId, clientName: fixedClientName, programId: fixedProgramId, programName: fixedProgramName, onClose }: AssignProgramDrawerProps) {
  const t = useTranslations("admin.programs");
  const fmt = useFormat();
  const queryClient = useQueryClient();
  const { show } = useToast();
  const gate = useTrainerBillingGate();

  const [programSearch, setProgramSearch] = useState("");
  const [clientSearch, setClientSearch] = useState("");
  const [selectedProgramId, setSelectedProgramId] = useState<number | null>(fixedProgramId ?? null);
  const [selectedClients, setSelectedClients] = useState<Set<number>>(new Set(fixedClientId != null ? [fixedClientId] : []));
  const [startDate, setStartDate] = useState(() => iso(nextOrSameMonday(new Date())));

  const programsQ = useQuery({ queryKey: queryKeys.trainerPrograms.all(), queryFn: trainerApi.programs, enabled: fixedProgramId == null });
  const clientsQ = useQuery({ queryKey: queryKeys.trainerClients.all(), queryFn: trainerApi.clients });
  const programDetailQ = useQuery({
    queryKey: queryKeys.trainerPrograms.detail(selectedProgramId ?? -1),
    queryFn: () => trainerApi.program(selectedProgramId as number),
    enabled: selectedProgramId != null,
  });

  const clients = useMemo(() => clientsQ.data ?? [], [clientsQ.data]);
  const candidates = fixedClientId != null ? clients.filter((c) => c.clientId === fixedClientId) : clients;

  // Who already runs this program (an active assignment of it) — those rows are disabled.
  const assignmentQs = useQueries({
    queries: candidates.map((c) => ({ queryKey: queryKeys.trainerProgramAssignments.forClient(c.clientId), queryFn: () => trainerApi.programAssignmentsForClient(c.clientId), enabled: selectedProgramId != null })),
  });
  const alreadyUsing = new Set(
    candidates.filter((c, i) => (assignmentQs[i]?.data ?? []).some((a) => a.programId === selectedProgramId && a.cancelledAt == null)).map((c) => c.clientId),
  );

  const startValid = isValidProgramStartDate(startDate);
  const occurrences = useMemo(() => (programDetailQ.data && startValid ? programOccurrences(programDetailQ.data.workouts, startDate) : []), [programDetailQ.data, startDate, startValid]);
  const summary = consequenceSummary(occurrences);

  // Existing workouts over the span the program would cover — the conflicts are computed per selected client from this.
  const calendarQ = useQuery({
    queryKey: queryKeys.trainerCalendar.range(summary?.firstDate ?? "", summary?.lastDate ?? ""),
    queryFn: () => trainerApi.calendarSessions(summary!.firstDate, summary!.lastDate),
    enabled: summary != null,
  });
  const chosen = [...selectedClients].filter((id) => !alreadyUsing.has(id));
  const conflictsByClient = chosen
    .map((id) => ({ id, conflicts: findConflicts(occurrences, (calendarQ.data ?? []).filter((s) => s.clientId === id)) }))
    .filter((x) => x.conflicts.length > 0);
  const nameOf = (id: number) => { const c = clients.find((x) => x.clientId === id); return c ? clientDisplayName(c) : fixedClientName ?? ""; };

  const filteredPrograms = (programsQ.data ?? []).filter((p) => p.name.toLowerCase().includes(programSearch.toLowerCase()));
  const filteredClients = candidates.filter((c) => c.clientEmail.toLowerCase().includes(clientSearch.toLowerCase()) || clientDisplayName(c).toLowerCase().includes(clientSearch.toLowerCase()));

  const isValid = selectedProgramId != null && chosen.length > 0 && startValid && summary != null;
  const dirty = (selectedProgramId !== (fixedProgramId ?? null)) || selectedClients.size > (fixedClientId != null ? 1 : 0) || startDate !== iso(nextOrSameMonday(new Date()));

  const toggleClient = (id: number) => setSelectedClients((prev) => { const next = new Set(prev); if (next.has(id)) next.delete(id); else next.add(id); return next; });

  const assign = useMutation({
    mutationFn: async () => {
      const results = await Promise.allSettled(chosen.map((clientId) => trainerApi.assignProgram(selectedProgramId as number, { clientId, startDate })));
      return results.map((r, i) => ({ clientId: chosen[i], result: r }));
    },
    onSuccess: (rows) => {
      const ok = rows.filter((r) => r.result.status === "fulfilled");
      const failed = rows.filter((r) => r.result.status === "rejected");
      for (const r of ok) queryClient.invalidateQueries({ queryKey: queryKeys.trainerProgramAssignments.forClient(r.clientId) });
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerPrograms.all() });
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerTemplates.usage() });
      queryClient.invalidateQueries({ queryKey: ["trainer-calendar"] });
      if (ok.length > 0) {
        const first = ok[0].result as PromiseFulfilledResult<{ occurrenceCount: number }>;
        show(ok.length === 1 ? t("assigned", { count: first.value.occurrenceCount, name: nameOf(ok[0].clientId) }) : t("assignedMany", { clients: ok.length }), "success");
      }
      if (failed.length > 0) {
        const conflict = failed.some((f) => f.result.status === "rejected" && f.result.reason instanceof ApiError && f.result.reason.status === 409);
        show(conflict ? t("assignConflict") : t("assignFailed"), "error");
      }
      if (failed.length === 0) onClose();
    },
  });

  // D-T5: the trigger stays visible and enabled-looking; a blocked trainer sees this dialog the moment it would have opened.
  if (gate.state !== "OK") {
    return <BillingBlockedDialog open onClose={onClose} reason={gate.state === "RESTRICTED" ? "restricted" : "overLimit"} currentPlan={gate.currentPlan} activeClients={gate.activeClients} maxClients={gate.maxClients} />;
  }

  const sectionLabel = (text: string) => (
    <p className="type-body-s" style={{ color: "var(--text-2)", fontWeight: 800, letterSpacing: "0.06em", textTransform: "uppercase" }}>{text}</p>
  );
  const rowStyle = (selected: boolean) => ({ borderRadius: "var(--r-control)", background: selected ? "var(--primary-tint)" : "var(--nested)", boxShadow: selected ? "inset 0 0 0 2px var(--primary)" : undefined });
  const name = programDetailQ.data?.name ?? fixedProgramName ?? "";

  return (
    <Drawer
      open
      onClose={onClose}
      width={520}
      title={fixedClientId != null ? t("assignDrawerTitle", { name: fixedClientName ?? "" }) : name ? `${t("assignDrawerTitleGeneric")} · ${name}` : t("assignDrawerTitleGeneric")}
      isDirty={dirty}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>{t("cancel")}</Button>
          <Button onClick={() => assign.mutate()} disabled={!isValid || assign.isPending} data-testid="assign-drawer-submit">
            {assign.isPending ? t("assigning") : chosen.length > 1 ? t("assignToN", { count: chosen.length }) : t("assignAction")}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-6" data-testid="assign-program-drawer">
        <div className="flex flex-col gap-2">
          {sectionLabel(t("title"))}
          {fixedProgramId != null ? (
            <div className="flex items-center gap-3 px-3 py-2.5" style={rowStyle(false)}>
              <Icon name="event_repeat" size={20} fill={1} color="var(--role)" />
              <span className="flex-1 min-w-0 truncate" style={{ fontWeight: 700 }}>{fixedProgramName}</span>
            </div>
          ) : (
            <>
              <TextField size="dense" leadingIcon="search" aria-label={t("title")} placeholder={t("searchProgramPlaceholder")} value={programSearch} onChange={(e) => setProgramSearch(e.target.value)} />
              <div className="flex flex-col gap-1.5 max-h-[200px] overflow-y-auto">
                {programsQ.isError ? (
                  <ErrorState inline onRetry={() => programsQ.refetch()} />
                ) : filteredPrograms.length === 0 ? (
                  <p className="type-body-s text-center py-3" style={{ color: "var(--text-3)" }}>{t("noProgramsFound")}</p>
                ) : (
                  filteredPrograms.map((p) => {
                    const selected = p.id === selectedProgramId;
                    return (
                      <button key={p.id} type="button" data-testid="assign-drawer-program-row" aria-pressed={selected} onClick={() => setSelectedProgramId(p.id)} className="lifey-button flex items-center gap-3 px-3 py-2.5 text-left" style={rowStyle(selected)}>
                        <Icon name="event_repeat" size={20} fill={1} color="var(--role)" />
                        <span className="flex-1 min-w-0 truncate" style={{ fontWeight: 700 }}>{p.name}</span>
                        {selected && <Icon name="check_circle" size={20} fill={1} color="var(--primary)" />}
                      </button>
                    );
                  })
                )}
              </div>
            </>
          )}
        </div>

        {fixedClientId == null && (
          <div className="flex flex-col gap-2">
            {sectionLabel(t("whoFor"))}
            <TextField size="dense" leadingIcon="search" aria-label={t("client")} placeholder={t("searchClientPlaceholder")} value={clientSearch} onChange={(e) => setClientSearch(e.target.value)} />
            <div className="flex flex-col gap-1.5 max-h-[240px] overflow-y-auto">
              {clientsQ.isError ? (
                <ErrorState inline onRetry={() => clientsQ.refetch()} />
              ) : filteredClients.length === 0 ? (
                <p className="type-body-s text-center py-3" style={{ color: "var(--text-3)" }}>{t("noClientsFound")}</p>
              ) : (
                filteredClients.map((c) => {
                  const using = alreadyUsing.has(c.clientId);
                  const flags = complianceFor(c);
                  const checked = selectedClients.has(c.clientId) && !using;
                  return (
                    <button key={c.clientId} type="button" data-testid="assign-drawer-client-row" disabled={using} aria-pressed={checked} onClick={() => toggleClient(c.clientId)} className="lifey-button flex items-center gap-3 px-3 py-2.5 text-left disabled:opacity-60" style={rowStyle(checked)}>
                      <Checkbox checked={checked} onChange={() => {}} aria-label={clientDisplayName(c)} />
                      <ClientAvatar clientId={c.clientId} email={c.clientEmail} size={32} />
                      <span className="flex-1 min-w-0 truncate" style={{ fontWeight: 700 }}>{clientDisplayName(c)}</span>
                      <span className="type-body-s shrink-0" style={{ color: using ? "var(--text-2)" : flags.inactive ? "var(--heart)" : "var(--text-2)", fontWeight: flags.inactive && !using ? 700 : 400 }}>
                        {using ? t("alreadyUsing") : flags.inactive ? t("inactiveDays", { count: flags.daysSinceLastLog }) : t("stateActive")}
                      </span>
                    </button>
                  );
                })
              )}
            </div>
          </div>
        )}

        <div className="flex flex-col gap-2">
          {sectionLabel(t("startDateLabel"))}
          <DateFields value={new Date(`${startDate}T00:00:00`)} onChange={(d) => d && setStartDate(iso(d))} error={startValid ? undefined : t("startDateHint")} hint={startValid ? t("startDateHint") : undefined} />
        </div>

        {summary && (
          <div className="flex flex-col gap-2 p-4" style={{ borderRadius: "var(--r-card)", background: "var(--nested)" }} data-testid="assign-consequences" aria-live="polite">
            <p>
              {t("consequence", { count: summary.count, from: fmt.shortDate(new Date(`${summary.firstDate}T00:00:00`)), to: fmt.shortDate(new Date(`${summary.lastDate}T00:00:00`)) })}
            </p>
            {conflictsByClient.map(({ id, conflicts }) => (
              <p key={id} className="inline-flex items-start gap-2" style={{ color: "var(--heart)", fontWeight: 600 }}>
                <Icon name="warning" size={18} />
                <span>
                  {t("conflicts", { name: nameOf(id), count: conflicts.length })}
                  <span className="block type-body-s" style={{ color: "var(--text-2)", fontWeight: 400 }}>
                    {conflicts.slice(0, 4).map((c) => `${fmt.shortDate(new Date(`${c.occurrence.date}T00:00:00`))}${c.occurrence.time ? ` ${c.occurrence.time}` : ""}`).join(" · ")}
                    {conflicts.length > 4 ? ` · +${conflicts.length - 4}` : ""}
                  </span>
                </span>
              </p>
            ))}
            {conflictsByClient.length > 0 && <p className="type-body-s" style={{ color: "var(--text-2)" }}>{t("conflictsNote")}</p>}
          </div>
        )}
      </div>
    </Drawer>
  );
}
