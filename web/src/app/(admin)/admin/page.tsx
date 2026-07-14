"use client";

import { useState } from "react";
import Link from "next/link";
import { useTranslations } from "next-intl";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { trainerApi } from "@/features/trainer/api";
import { queryKeys } from "@/lib/api/queryKeys";
import { useToast } from "@/lib/hooks/useToast";
import { useSessionStore } from "@/features/auth/store";
import { ClientCard } from "@/features/trainer/components/ClientCard";
import { ClientListModal } from "@/features/trainer/components/ClientListModal";
import { ClientSortSelect } from "@/features/trainer/components/ClientSortSelect";
import { NeedsAttentionSection } from "@/features/trainer/components/NeedsAttentionSection";
import { sortClients, type ClientSortOption } from "@/features/trainer/compliance";
import { ErrorState } from "@/components/status/ErrorState";
import { Skeleton } from "@/components/status/Skeleton";

const MODAL_SEEN_KEY = "lifey-admin-client-modal-shown";
const SORT_KEY = "lifey-admin-client-sort";

function isSortOption(value: string | null): value is ClientSortOption {
  return value === "recent" || value === "leastActive" || value === "mostMissed" || value === "weightOverdue";
}

export default function AdminDashboardPage() {
  const t = useTranslations("admin.dashboard");
  const queryClient = useQueryClient();
  const { show } = useToast();
  const { user } = useSessionStore();
  const [modalDismissed, setModalDismissed] = useState(
    () => typeof window !== "undefined" && sessionStorage.getItem(MODAL_SEEN_KEY) === "1",
  );
  const [sort, setSort] = useState<ClientSortOption>(() => {
    if (typeof window === "undefined") return "recent";
    const stored = sessionStorage.getItem(SORT_KEY);
    return isSortOption(stored) ? stored : "recent";
  });

  const updateSort = (value: ClientSortOption) => {
    setSort(value);
    try {
      sessionStorage.setItem(SORT_KEY, value);
    } catch {
      /* ignore */
    }
  };

  const { data: clients, isLoading, isError, refetch } = useQuery({
    queryKey: queryKeys.trainerClients.all(),
    queryFn: trainerApi.clients,
  });

  const revokeMutation = useMutation({
    mutationFn: (clientId: number) => trainerApi.revokeClient(clientId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.trainerClients.all() });
      show(t("relationshipEnded"), "success");
    },
    onError: () => show(t("relationshipEndFailed"), "error"),
  });

  const dismissModal = () => {
    setModalDismissed(true);
    try {
      sessionStorage.setItem(MODAL_SEEN_KEY, "1");
    } catch {
      /* ignore */
    }
  };

  return (
    <div className="flex flex-col gap-3.5">
      <div
        className="flex items-center justify-between rounded-[var(--r-card)] h-[62px] px-3.5 pl-5.5"
        style={{ background: "var(--surface-high)" }}
      >
        <div>
          <p className="text-lg font-extrabold tracking-tight" style={{ color: "var(--on-surface)" }}>
            {t("title")}
          </p>
          <p className="text-[11px] font-medium" style={{ color: "var(--on-surface-variant)" }}>
            {t("subtitleCount", { count: clients?.length ?? 0 })}
          </p>
        </div>
        <div className="flex items-center gap-2.5">
          {clients && clients.length > 1 && <ClientSortSelect value={sort} onChange={updateSort} />}
          <Link
            href="/admin/invites"
            className="flex items-center gap-2 rounded-2xl px-4 py-2.5 text-[13px] font-extrabold"
            style={{ background: "var(--tertiary)", color: "#161611" }}
          >
            <span className="material-symbols-rounded text-[19px]">person_add</span>
            {t("inviteClient")}
          </Link>
          <div
            className="w-[42px] h-[42px] rounded-2xl flex items-center justify-center text-[15px] font-extrabold"
            style={{ background: "var(--tertiary)", color: "#161611" }}
          >
            {user?.email.charAt(0).toUpperCase()}
          </div>
        </div>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3.5">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} variant="card" className="h-[170px]" />
          ))}
        </div>
      ) : isError ? (
        <ErrorState onRetry={refetch} />
      ) : !clients || clients.length === 0 ? (
        <div className="rounded-2xl p-8 text-center" style={{ background: "var(--surface)" }}>
          <div
            className="w-[58px] h-[58px] rounded-[18px] flex items-center justify-center mx-auto mb-3"
            style={{ background: "var(--surface-container)", color: "var(--tertiary)" }}
          >
            <span className="material-symbols-rounded text-3xl">group</span>
          </div>
          <p className="text-[15px] font-extrabold" style={{ color: "var(--on-surface)" }}>
            {t("noClientsTitle")}
          </p>
          <p className="text-xs mt-1" style={{ color: "var(--on-surface-variant)" }}>
            {t("noClientsBody")}
          </p>
          <Link
            href="/admin/invites"
            className="inline-flex items-center gap-2 rounded-2xl px-4.5 py-2.5 text-[13px] font-extrabold mt-4"
            style={{ background: "var(--tertiary)", color: "#161611" }}
          >
            <span className="material-symbols-rounded text-lg">person_add</span>
            {t("inviteFirst")}
          </Link>
        </div>
      ) : (
        <>
          <NeedsAttentionSection clients={clients} />
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3.5">
            {sortClients(clients, sort).map((c) => (
              <ClientCard
                key={c.clientId}
                client={c}
                onRevoke={(id) => revokeMutation.mutate(id)}
                revoking={revokeMutation.isPending}
              />
            ))}
          </div>
          {!modalDismissed && <ClientListModal clients={clients} onClose={dismissModal} />}
        </>
      )}
    </div>
  );
}
