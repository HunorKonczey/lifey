"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { ApiError } from "@/lib/api/client";
import { useToast } from "@/lib/hooks/useToast";
import { DatePicker } from "@/components/ui/DatePicker";
import { ErrorState } from "@/components/status/ErrorState";
import { ClientAvatar, nameFor } from "./ClientAvatar";
import { nextOrSameMonday, isValidProgramStartDate, programEndDate } from "../program";
import { format } from "date-fns";

interface AssignProgramDrawerProps {
  /* Client-detail entry point: the client is fixed, the trainer picks a program. */
  clientId?: number;
  clientName?: string;
  /* Program list/builder entry point: the program is fixed, the trainer picks a client. */
  programId?: number;
  programName?: string;
  onClose: () => void;
}

export function AssignProgramDrawer({
  clientId: fixedClientId, clientName: fixedClientName,
  programId: fixedProgramId, programName: fixedProgramName,
  onClose,
}: AssignProgramDrawerProps) {
  const t = useTranslations("admin.programs");
  const queryClient = useQueryClient();
  const { show } = useToast();

  const [programSearch, setProgramSearch] = useState("");
  const [clientSearch, setClientSearch] = useState("");
  const [selectedProgramId, setSelectedProgramId] = useState<number | null>(fixedProgramId ?? null);
  const [selectedClientId, setSelectedClientId] = useState<number | null>(fixedClientId ?? null);
  const [startDate, setStartDate] = useState(() => format(nextOrSameMonday(new Date()), "yyyy-MM-dd"));

  const programsQ = useQuery({
    queryKey: queryKeys.trainerPrograms.all(),
    queryFn: trainerApi.programs,
    enabled: fixedProgramId == null,
  });
  const clientsQ = useQuery({
    queryKey: queryKeys.trainerClients.all(),
    queryFn: trainerApi.clients,
    enabled: fixedClientId == null,
  });
  const programDetailQ = useQuery({
    queryKey: queryKeys.trainerPrograms.detail(selectedProgramId ?? -1),
    queryFn: () => trainerApi.program(selectedProgramId as number),
    enabled: selectedProgramId != null,
  });

  const filteredPrograms = (programsQ.data ?? []).filter((p) =>
    p.name.toLowerCase().includes(programSearch.toLowerCase()),
  );
  const filteredClients = (clientsQ.data ?? []).filter((c) =>
    c.clientEmail.toLowerCase().includes(clientSearch.toLowerCase()) ||
    nameFor(c.clientEmail).toLowerCase().includes(clientSearch.toLowerCase()),
  );

  const clientName = fixedClientName ?? nameFor(clientsQ.data?.find((c) => c.clientId === selectedClientId)?.clientEmail ?? "");

  const startValid = isValidProgramStartDate(startDate);
  const minStartDate = new Date(`${format(nextOrSameMonday(new Date()), "yyyy-MM-dd")}T00:00:00`);
  const isValid = selectedProgramId != null && selectedClientId != null && startValid;

  const weeksCount = programDetailQ.data?.weeksCount ?? 0;
  const occurrenceCount = programDetailQ.data?.workouts.length ?? 0;
  const endDate = weeksCount > 0 && startValid ? programEndDate(startDate, weeksCount) : null;

  const assignMutation = useMutation({
    mutationFn: () =>
      trainerApi.assignProgram(selectedProgramId as number, { clientId: selectedClientId as number, startDate }),
    onSuccess: (res) => {
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerProgramAssignments.forClient(selectedClientId as number) });
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerPrograms.all() });
      queryClient.invalidateQueries({ queryKey: ["trainer-calendar"] });
      show(t("assigned", { count: res.occurrenceCount, name: clientName }), "success");
      onClose();
    },
    onError: (e) => {
      if (e instanceof ApiError && e.status === 409) {
        show(t("assignConflict"), "error");
      } else {
        show(t("assignFailed"), "error");
      }
    },
  });

  return (
    <div className="fixed inset-0 z-50 flex justify-end" data-testid="assign-program-drawer">
      <div className="absolute inset-0" style={{ background: "rgba(8,9,6,.45)" }} onClick={onClose} />
      <div
        className="relative w-full max-w-[420px] h-full flex flex-col gap-4 p-5.5 overflow-y-auto"
        style={{ background: "var(--surface-container)", boxShadow: "-20px 0 50px rgba(0,0,0,.45)" }}
      >
        <div className="flex items-center justify-between">
          <p className="text-lg font-extrabold tracking-tight" style={{ color: "var(--on-surface)" }}>
            {fixedClientId != null ? t("assignDrawerTitle", { name: clientName }) : t("assignDrawerTitleGeneric")}
          </p>
          <button onClick={onClose} style={{ color: "var(--on-surface-variant)" }} aria-label={t("cancel")}>
            <span className="material-symbols-rounded text-xl">close</span>
          </button>
        </div>

        <div className="flex flex-col gap-2">
          <p className="text-[11px] font-bold tracking-wider uppercase" style={{ color: "var(--muted)" }}>
            {t("title")}
          </p>
          {fixedProgramId != null ? (
            <div className="flex items-center gap-3 rounded-2xl px-3 py-2.5" style={{ background: "var(--surface)" }}>
              <span
                className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0"
                style={{ background: "var(--surface-high)", color: "var(--tertiary)" }}
              >
                <span className="material-symbols-rounded text-lg">event_repeat</span>
              </span>
              <span className="flex-1 min-w-0 text-[13.5px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                {fixedProgramName}
              </span>
            </div>
          ) : (
            <>
              <div className="rounded-2xl h-11 flex items-center gap-2.5 px-4" style={{ background: "var(--surface)" }} data-ring-frame>
                <span className="material-symbols-rounded text-lg" style={{ color: "var(--muted)" }}>search</span>
                <input
                  value={programSearch}
                  onChange={(e) => setProgramSearch(e.target.value)}
                  placeholder={t("searchProgramPlaceholder")}
                  className="flex-1 bg-transparent outline-none text-sm"
                  style={{ color: "var(--on-surface)" }}
                />
              </div>
              <div className="flex flex-col gap-1.5 max-h-[180px] overflow-y-auto">
                {programsQ.isError ? (
                  <ErrorState inline onRetry={() => programsQ.refetch()} />
                ) : filteredPrograms.length === 0 ? (
                  <p className="text-xs text-center py-3" style={{ color: "var(--muted)" }}>{t("noProgramsFound")}</p>
                ) : (
                  filteredPrograms.map((program) => {
                    const selected = program.id === selectedProgramId;
                    return (
                      <button
                        key={program.id}
                        data-testid="assign-drawer-program-row"
                        onClick={() => setSelectedProgramId(program.id)}
                        className="flex items-center gap-3 rounded-2xl px-3 py-2.5 transition-colors text-left"
                        style={{
                          background: selected ? "rgba(110,154,106,.14)" : "transparent",
                          border: selected ? "1.5px solid var(--tertiary)" : "1.5px solid transparent",
                        }}
                      >
                        <span
                          className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0"
                          style={{ background: "var(--surface-high)", color: "var(--tertiary)" }}
                        >
                          <span className="material-symbols-rounded text-lg">event_repeat</span>
                        </span>
                        <span className="flex-1 min-w-0 text-[13.5px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                          {program.name}
                        </span>
                        {selected && (
                          <span className="material-symbols-rounded text-xl" style={{ color: "var(--tertiary)", fontVariationSettings: "'FILL' 1" }}>
                            check_circle
                          </span>
                        )}
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
            <p className="text-[11px] font-bold tracking-wider uppercase" style={{ color: "var(--muted)" }}>
              {t("client")}
            </p>
            <div className="rounded-2xl h-11 flex items-center gap-2.5 px-4" style={{ background: "var(--surface)" }} data-ring-frame>
              <span className="material-symbols-rounded text-lg" style={{ color: "var(--muted)" }}>search</span>
              <input
                value={clientSearch}
                onChange={(e) => setClientSearch(e.target.value)}
                placeholder={t("searchClientPlaceholder")}
                className="flex-1 bg-transparent outline-none text-sm"
                style={{ color: "var(--on-surface)" }}
              />
            </div>
            <div className="flex flex-col gap-1.5 max-h-[180px] overflow-y-auto">
              {clientsQ.isError ? (
                <ErrorState inline onRetry={() => clientsQ.refetch()} />
              ) : filteredClients.length === 0 ? (
                <p className="text-xs text-center py-3" style={{ color: "var(--muted)" }}>{t("noClientsFound")}</p>
              ) : (
                filteredClients.map((c) => {
                  const selected = c.clientId === selectedClientId;
                  return (
                    <button
                      key={c.clientId}
                      data-testid="assign-drawer-client-row"
                      onClick={() => setSelectedClientId(c.clientId)}
                      className="flex items-center gap-3 rounded-2xl px-3 py-2.5 transition-colors text-left"
                      style={{
                        background: selected ? "rgba(110,154,106,.14)" : "transparent",
                        border: selected ? "1.5px solid var(--tertiary)" : "1.5px solid transparent",
                      }}
                    >
                      <ClientAvatar clientId={c.clientId} email={c.clientEmail} size={32} />
                      <span className="flex-1 min-w-0 text-[13.5px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                        {nameFor(c.clientEmail)}
                      </span>
                      {selected && (
                        <span className="material-symbols-rounded text-xl" style={{ color: "var(--tertiary)", fontVariationSettings: "'FILL' 1" }}>
                          check_circle
                        </span>
                      )}
                    </button>
                  );
                })
              )}
            </div>
          </div>
        )}

        <div className="flex flex-col gap-2">
          <p className="text-[11px] font-bold tracking-wider uppercase" style={{ color: "var(--muted)" }}>
            {t("startDateLabel")}
          </p>
          <DatePicker value={startDate} onChange={setStartDate} min={minStartDate} hasError={!startValid} />
          <p className="text-[11px]" style={{ color: startValid ? "var(--on-surface-variant)" : "var(--error)" }}>
            {t("startDateHint")}
          </p>
        </div>

        {isValid && occurrenceCount > 0 && endDate && (
          <div className="rounded-2xl p-4" style={{ background: "var(--surface)" }}>
            <p className="text-[13px] font-bold" style={{ color: "var(--on-surface)" }}>
              {t("previewLine", { count: occurrenceCount, weeks: weeksCount, endDate })}
            </p>
          </div>
        )}

        <div className="mt-auto flex gap-2.5 pt-2">
          <button onClick={onClose} className="flex-1 text-center text-[13.5px] font-bold py-3 rounded-2xl" style={{ color: "var(--on-surface-variant)" }}>
            {t("cancel")}
          </button>
          <button
            onClick={() => assignMutation.mutate()}
            disabled={!isValid || assignMutation.isPending}
            data-testid="assign-drawer-submit"
            className="flex-[2] text-center rounded-2xl py-3 text-[13.5px] font-extrabold disabled:opacity-40"
            style={{ background: "var(--tertiary)", color: "#161611" }}
          >
            {assignMutation.isPending ? t("assigning") : t("assignAction")}
          </button>
        </div>
      </div>
    </div>
  );
}
