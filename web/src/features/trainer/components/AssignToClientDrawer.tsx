"use client";

import { useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { format } from "date-fns";
import { enUS, hu } from "date-fns/locale";
import { trainerApi } from "../api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { useLocale } from "@/lib/hooks/useLocale";
import { ErrorState } from "@/components/status/ErrorState";
import { ClientAvatar, nameFor } from "./ClientAvatar";
import type { ContentType } from "../types";

const DATE_LOCALES = { en: enUS, hu } as const;

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
  const dateLocale = DATE_LOCALES[useLocale((s) => s.locale)];
  const queryClient = useQueryClient();
  const { show } = useToast();
  const [search, setSearch] = useState("");
  const [selectedClientId, setSelectedClientId] = useState<number | null>(null);

  const clientsQ = useQuery({ queryKey: queryKeys.trainerClients.all(), queryFn: trainerApi.clients });
  const assignmentsQ = useQuery({
    queryKey: queryKeys.trainerAssignments.forClient(selectedClientId ?? -1),
    queryFn: () => trainerApi.assignmentsForClient(selectedClientId!),
    enabled: selectedClientId != null,
  });

  const filteredClients = (clientsQ.data ?? []).filter((c) =>
    c.clientEmail.toLowerCase().includes(search.toLowerCase()) || nameFor(c.clientEmail).toLowerCase().includes(search.toLowerCase()),
  );

  const previousAssignment = useMemo(
    () => (assignmentsQ.data ?? []).find((a) => a.contentType === contentType && a.sourceId === sourceId) ?? null,
    [assignmentsQ.data, contentType, sourceId],
  );

  const assignMutation = useMutation({
    mutationFn: () => trainerApi.assign({ clientId: selectedClientId!, contentType, sourceId }),
    onSuccess: () => {
      const client = clientsQ.data?.find((c) => c.clientId === selectedClientId);
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerAssignments.forClient(selectedClientId!) });
      show(t("assigned", { name: client ? nameFor(client.clientEmail) : "" }), "success");
      onClose();
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

        <div className="rounded-2xl h-[46px] flex items-center gap-2.5 px-3.5" style={{ background: "var(--surface)" }}>
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
              const selected = selectedClientId === c.clientId;
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
                  <span className="flex-1 text-[13.5px] font-bold truncate" style={{ color: "var(--on-surface)" }}>
                    {nameFor(c.clientEmail)}
                  </span>
                  {selected ? (
                    <span className="material-symbols-rounded text-xl" style={{ color: "var(--tertiary)", fontVariationSettings: "'FILL' 1" }}>
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

        {previousAssignment && (
          <div
            className="rounded-2xl p-3.5 flex gap-2.5"
            style={{ background: "rgba(110,154,106,.14)", border: "1px solid rgba(110,154,106,.35)" }}
          >
            <span className="material-symbols-rounded text-lg shrink-0" style={{ color: "var(--tertiary)" }}>history</span>
            <p className="text-xs leading-relaxed" style={{ color: "var(--on-surface)" }}>
              {t("alreadyAssignedPrefix")}{" "}
              <span style={{ fontWeight: 800 }}>{format(new Date(previousAssignment.assignedAt), "MMM d.", { locale: dateLocale })}</span>
              {t("alreadyAssignedSuffix")}
            </p>
          </div>
        )}

        <div className="mt-auto flex gap-2.5 pt-2">
          <button onClick={onClose} className="flex-1 text-center text-[13.5px] font-bold py-3 rounded-2xl" style={{ color: "var(--on-surface-variant)" }}>
            {t("cancel")}
          </button>
          <button
            onClick={() => assignMutation.mutate()}
            disabled={selectedClientId == null || assignMutation.isPending}
            data-testid="assign-drawer-submit"
            className="flex-[2] text-center rounded-2xl py-3 text-[13.5px] font-extrabold disabled:opacity-40"
            style={{ background: "var(--tertiary)", color: "#161611" }}
          >
            {assignMutation.isPending ? t("assigning") : t("assign")}
          </button>
        </div>
      </div>
    </div>
  );
}
